import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../crypt/string_armor.dart';

// ─────────────────────────────────────────────────────────────────────
// AGENT CLIENT — HTTP client wearing a real-device User-Agent
// ─────────────────────────────────────────────────────────────────────
// Outgoing requests inherit the actual brand/model/SDK from the running
// device, plus encoded Chrome and WebKit version stamps. Same UA is
// applied to the in-app WebView, so traffic from both stays consistent.
// ─────────────────────────────────────────────────────────────────────

const List<int> _kChromeRev = <int>[
  0x7e, 0x2b, 0x26, 0x8c, 0xc8, 0x59, 0x6b, 0x08, 0xe1, 0xdd, 0xaf, 0x53,
  0xa8, 0x39, 0xb0, 0x02,
];

const List<int> _kWebKitRev = <int>[
  0x7a, 0x2b, 0x20, 0x8c, 0xcb, 0x41, 0x5b, 0x26, 0xd1, 0xdd,
];

class AgentClient extends http.BaseClient {
  final http.Client _delegate = http.Client();
  String _ua = 'Mozilla/5.0';
  bool _ready = false;

  Future<void> prepare() async {
    if (_ready) return;
    final chrome = _safeUnveil(_kChromeRev, '131.0.0.0');
    final webkit = _safeUnveil(_kWebKitRev, '537.36');

    try {
      final probe = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await probe.androidInfo;
        final brand = info.brand;
        final model = info.model;
        final api = info.version.sdkInt;
        final build = info.display.isNotEmpty ? info.display : info.id;
        _ua = 'Mozilla/5.0 (Linux; Android $api; $brand $model '
            'Build/$build) AppleWebKit/$webkit (KHTML, like Gecko) '
            'Chrome/$chrome Mobile Safari/$webkit';
      } else if (Platform.isIOS) {
        final info = await probe.iosInfo;
        final ver = info.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${info.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      _ua = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) '
          'AppleWebKit/$webkit (KHTML, like Gecko) '
          'Chrome/$chrome Mobile Safari/$webkit';
    }
    _ready = true;
  }

  String get userAgent => _ua;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => _ua);
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

String _safeUnveil(List<int> bytes, String fallback) {
  if (bytes.isEmpty) return fallback;
  final v = unveil(bytes);
  return v.isEmpty ? fallback : v;
}

/// Process-wide instance reused by every service that talks to the network.
final AgentClient agent = AgentClient();
