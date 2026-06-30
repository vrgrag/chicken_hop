import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/agent_client.dart';
import '../core/alert_dispatcher.dart';
import '../core/local_vault.dart';
import '../core/net_sensor.dart';
import '../setup/app_facade.dart';
import 'offline_stage.dart';

// ─────────────────────────────────────────────────────────────────────
// PORTAL STAGE — full-screen WebView shell
// ─────────────────────────────────────────────────────────────────────
// Implements every fix called out in gray_part_pitfalls.md:
//
//   #3/#4 → connectivity drops are debounced for 700 ms before showing
//           the styled offline screen; WebView native error pages are
//           hidden the instant `onWebResourceError` fires.
//   §custom-screens → landscape applies viewPadding.left/right so the
//           camera notch never overlaps the WebView content.
//   §keyboard-three-layer → AndroidManifest uses adjustResize, the
//           Scaffold has resizeToAvoidBottomInset:false, and we inject
//           a single-shot `scrollIntoView({behavior:'auto'})` patcher.
//   §safe-area-css-kill → JS removes `--safe-area-inset-*` CSS vars and
//           forces `viewport-fit=contain` so notched devices don't show
//           white bars at the top/bottom.
//   §too_many_redirects → loop retries up to 3 times before bailing.
// ─────────────────────────────────────────────────────────────────────

/// Optional pre-warm hook (kept symmetric with the deferred import in
/// boot_gate.dart). Currently a no-op — left in place for future engine
/// warm-up work.
Future<void> warmUpPortalEngine() async {}

class PortalStage extends StatefulWidget {
  final String landingUrl;
  final LocalVault vault;
  final AlertDispatcher alerts;
  final NetSensor sensor;

  const PortalStage({
    super.key,
    required this.landingUrl,
    required this.vault,
    required this.alerts,
    required this.sensor,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _offlineDebounce;

  bool _spinning = true;
  bool _offlineShown = false;
  String? _lastMainFrameUrl;
  int _redirectRetries = 0;

  static const _kReachable = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinning = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinning = false);
          _redirectRetries = 0;
          _injectSafeAreaKiller();
          _injectKeyboardScroll();
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          final blurb = err.description.toLowerCase();

          // 1) Redirect-loop retry first.
          final loop = blurb.contains('too_many_redirects') ||
              blurb.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop &&
              _lastMainFrameUrl != null &&
              _redirectRetries < 3) {
            _redirectRetries++;
            _controller.loadRequest(Uri.parse(_lastMainFrameUrl!));
            return;
          }

          // 2) Cover the WebView's native error page immediately.
          if (mounted) setState(() => _spinning = true);

          // 3) DNS / disconnect → skip the redundant DNS probe.
          final dnsLike = blurb.contains('name_not_resolved') ||
              blurb.contains('err_name_not_resolved') ||
              blurb.contains('internet_disconnected') ||
              blurb.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsLike) {
            _goOfflineImmediate();
          } else {
            _checkAndGoOffline();
          }
        },
        onHttpError: (_) {},
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          final scheme = uri.scheme;
          if (scheme == 'http' ||
              scheme == 'https' ||
              scheme == 'about' ||
              scheme == 'data' ||
              scheme == 'blob') {
            if (request.isMainFrame) _lastMainFrameUrl = request.url;
            return NavigationDecision.navigate;
          }
          _openExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _configureAndroidSurface();
    _controller.loadRequest(Uri.parse(widget.landingUrl));

    widget.alerts.onPortalRedirect = (url) {
      if (mounted) _controller.loadRequest(Uri.parse(url));
    };

    _connSub = widget.sensor.flow.listen((statuses) {
      final reachable = statuses.any(_kReachable.contains);
      if (reachable) {
        _offlineDebounce?.cancel();
        return;
      }
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(
        const Duration(milliseconds: AppFacade.offlineDebounceMs),
        _goOfflineImmediate,
      );
    });
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  void _configureAndroidSurface() {
    if (Platform.isAndroid &&
        _controller.platform is AndroidWebViewController) {
      final native = _controller.platform as AndroidWebViewController;
      native.setMediaPlaybackRequiresUserGesture(false);
      native.setOnShowFileSelector(_onFileSelector);
      final cookieMgr = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookieMgr.setAcceptThirdPartyCookies(native, true);
    }
  }

  Future<List<String>> _onFileSelector(FileSelectorParams params) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (picked != null && picked.files.isNotEmpty) {
        return picked.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      }
    } catch (_) {}
    return const <String>[];
  }

  Future<void> _checkAndGoOffline() async {
    if (_offlineShown) return;
    final live = await widget.sensor.isLive();
    if (live || !mounted) return;
    _goOfflineImmediate();
  }

  void _goOfflineImmediate() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final ctrl = _controller;
    () async {
      final current = await ctrl.currentUrl() ?? widget.landingUrl;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OfflineStage(
            onRetryBuilder: (_) => PortalStage(
              landingUrl: current,
              vault: widget.vault,
              alerts: widget.alerts,
              sensor: widget.sensor,
            ),
          ),
        ),
      );
    }();
  }

  void _injectKeyboardScroll() {
    _controller.runJavaScript('''
(function(){
  if (window.__chKbWired) return; window.__chKbWired = true;
  function isField(el){ return el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.isContentEditable); }
  function bring(){
    var el = document.activeElement;
    if(!isField(el)) return;
    var vp = window.visualViewport;
    if(vp){
      var rect = el.getBoundingClientRect();
      var bottom = vp.offsetTop + vp.height;
      if(rect.bottom > bottom - 20 || rect.top < vp.offsetTop){
        el.scrollIntoView({behavior:'auto', block:'nearest'});
      }
    } else {
      el.scrollIntoView({behavior:'auto', block:'nearest'});
    }
  }
  document.addEventListener('focusin', function(e){
    if(isField(e.target)) setTimeout(bring, 350);
  });
  if(window.visualViewport){
    var lastH = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if(h < lastH) setTimeout(bring, 120);
      lastH = h;
    });
  }
})();
''');
  }

  void _injectSafeAreaKiller() {
    _controller.runJavaScript(r'''
(function(){
  if(window.__chSaWired) return; window.__chSaWired = true;
  var TAG = '__ch_sa_kill';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
    '}' +
    'html,body,#__nuxt,#__next,#__layout,#app,#root,#__app{' +
      'padding-top:0!important;padding-left:0!important;padding-right:0!important;' +
      'margin-top:0!important;' +
    '}';
  function isKbOpen(){
    if(!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }
  function apply(){
    if(isKbOpen()) return; // do not relayout during keyboard animation
    var head = document.head || document.documentElement;
    if(!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if(meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content') || '')){
      var c = (meta.getAttribute('content') || '').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      meta.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var node = document.getElementById(TAG);
    if(!node){
      node = document.createElement('style');
      node.id = TAG;
      head.appendChild(node);
    }
    if(node.textContent !== CSS) node.textContent = CSS;
    if(head.lastElementChild !== node) head.appendChild(node);
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply, 80);
      setTimeout(apply, 400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<bool> _onBackPressed() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _offlineDebounce?.cancel();
    widget.alerts.onPortalRedirect = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;

    // Top inset only in portrait (landscape goes fully immersive);
    // left/right insets only in landscape to dodge the camera notch.
    final padding = landscape
        ? EdgeInsets.only(
            left: media.viewPadding.left,
            right: media.viewPadding.right,
          )
        : EdgeInsets.only(top: media.viewPadding.top);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // CRITICAL: must be false so that adjustResize from the
        // manifest is the only entity resizing for the keyboard.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: padding,
              child: WebViewWidget(controller: _controller),
            ),
            if (_spinning)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFC93C),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
