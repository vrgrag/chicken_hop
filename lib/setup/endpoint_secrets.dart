import '../crypt/string_armor.dart';

// ─────────────────────────────────────────────────────────────────────
// ENDPOINT SECRETS — opaque payloads for the verdict endpoint
// ─────────────────────────────────────────────────────────────────────
// The verdict endpoint is the back-end URL that decides whether a user
// gets the portal (WebView) or the local puzzle. The host and path are
// stored as two independent opaque byte streams so neither half appears
// as a recognisable URL prefix in static analysis.
//
// To rotate after changing the seed in string_armor.dart:
//   `dart run tool/seed_secrets.dart`
// and paste the new arrays below.
// ─────────────────────────────────────────────────────────────────────

const List<int> _verdictHost = <int>[
  0x27, 0x6c, 0x63, 0xd2, 0x8b, 0x4d, 0x74, 0x09, 0xb2, 0xb5, 0xc6, 0x30,
  0xc3, 0x5c, 0xde, 0x6c, 0x74, 0x05, 0xf6, 0xe2, 0x61, 0x16, 0xbc, 0x3e,
  0xda, 0x31, 0x1b, 0x9c, 0x8e, 0x34,
];

const List<int> _verdictPath = <int>[
  0x60, 0x7b, 0x78, 0xcc, 0x9e, 0x1e, 0x3c, 0x08, 0xa1, 0xb5, 0xdf, 0x53,
  0xa8, 0x39, 0xb0, 0x02, 0x1c,
];

/// Returns the full verdict-decider URL, e.g.
/// `https://chickennhop.com/config.php`.
String resolveVerdictEndpoint() {
  final host = unveil(_verdictHost);
  final path = unveil(_verdictPath);
  if (host.isEmpty || path.isEmpty) return '';
  return '$host$path';
}
