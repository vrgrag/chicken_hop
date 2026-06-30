import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Thin WebView wrapper used by the local puzzle menu to surface the
/// Privacy Policy and Support pages. Lightweight on purpose — no
/// connectivity probes, no notch handling — these pages are static and
/// always opened from a deliberate menu tap.
class InfoStage extends StatefulWidget {
  final String title;
  final String url;

  const InfoStage({super.key, required this.title, required this.url});

  @override
  State<InfoStage> createState() => _InfoStageState();
}

class _InfoStageState extends State<InfoStage> {
  late final WebViewController _controller;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8FD16F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5B3A1B),
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 2,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_busy)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFFFE0B2),
              valueColor: AlwaysStoppedAnimation(Color(0xFFFF8C00)),
            ),
        ],
      ),
    );
  }
}
