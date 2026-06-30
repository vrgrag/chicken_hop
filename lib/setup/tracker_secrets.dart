import '../crypt/string_armor.dart';

// ─────────────────────────────────────────────────────────────────────
// TRACKER SECRETS — opaque payloads for AppsFlyer + Firebase
// ─────────────────────────────────────────────────────────────────────
// `_trackerDevKey` and `_firebaseSender` start empty: the resolvers
// return empty strings until populated. The attribution flow degrades
// gracefully (no SDK init, no GCD retry) when these are unset.
//
// Fill them by editing tool/seed_secrets.dart with the plaintext values
// and running `dart run tool/seed_secrets.dart`. Paste the resulting
// arrays here. Re-encode after every change to the seed phrase.
// ─────────────────────────────────────────────────────────────────────

// AppsFlyer Dev Key.
const List<int> _trackerDevKey = <int>[
  0x27, 0x4f, 0x51, 0x91, 0x90, 0x25, 0x21, 0x6b, 0xe9, 0xe4, 0xcd, 0x02,
  0xc5, 0x6a, 0xe5, 0x56, 0x78, 0x59, 0xf2, 0x86, 0x5b, 0x1b, 0xd1, 0x3e,
  0xda, 0x31, 0x1b, 0x9c,
];

// Firebase project number (sender ID).
const List<int> _firebaseSender = <int>[
  0x79, 0x2e, 0x20, 0x9a, 0xc9, 0x44, 0x6d, 0x16, 0xe2, 0xe9, 0x9d, 0x62,
  0xa8, 0x39, 0xb0,
];

// GCD endpoint host (already known — independent of credentials).
const List<int> _gcdHost = <int>[
  0x27, 0x6c, 0x63, 0xd2, 0x8b, 0x4d, 0x74, 0x09, 0xb6, 0xbe, 0xcb, 0x20,
  0xcc, 0x52, 0x9e, 0x63, 0x6c, 0x1a, 0xf5, 0xaa, 0x6e, 0x00, 0xb4, 0x4c,
  0xf4, 0x52, 0x74, 0xf1, 0x8e, 0x34, 0xd3, 0x80, 0xdf,
];

const List<int> _gcdPath = <int>[
  0x60, 0x71, 0x79, 0xd1, 0x8c, 0x16, 0x37, 0x4a, 0x8e, 0xb9, 0xce, 0x27,
  0xc9, 0x16, 0xc6, 0x36, 0x32, 0x5a, 0xa9, 0xcc, 0x02, 0x79, 0xd1, 0x3e,
];

String resolveTrackerKey() => unveil(_trackerDevKey);

String resolveFirebaseSender() => unveil(_firebaseSender);

/// Builds the AppsFlyer GCD (Get Conversion Data) request URL.
/// Empty when GCD host is unconfigured.
String resolveGcdUrl({required String appId, required String deviceId}) {
  final host = unveil(_gcdHost);
  final path = unveil(_gcdPath);
  if (host.isEmpty) return '';
  return '$host$path$appId?device_id=$deviceId';
}
