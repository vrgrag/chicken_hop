// ignore_for_file: avoid_print
//
// Run with: `dart run tool/seed_secrets.dart`
//
// Encodes plain strings into opaque byte arrays consumable by
// `lib/crypt/string_armor.dart`. Mirrors the runtime PRNG so the same
// seed phrase (declared in string_armor.dart) drives both sides.
//
// Fill the `_targets` map with whatever needs to be hidden in this build.
// Output is grouped by symbolic name and ready to paste into the
// corresponding setup/*.dart file.

import 'dart:math';
import 'dart:typed_data';

const List<String> _seedTokens = <String>[
  'chicken',
  '-',
  'hop',
  '-',
  'roost',
  '42',
];

int _seedFromTokens() {
  var hash = 0x811c9dc5;
  for (final t in _seedTokens) {
    for (final c in t.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
  }
  if (hash == 0) hash = 1;
  return hash & 0x7FFFFFFF;
}

class _Stream {
  int _state;
  _Stream(int seed) : _state = seed == 0 ? 1 : (seed & 0x7FFFFFFF);

  int nextByte() {
    const a = 48271;
    const m = 0x7FFFFFFF;
    const q = m ~/ a;
    const r = m % a;
    final hi = _state ~/ q;
    final lo = _state % q;
    var t = a * lo - r * hi;
    if (t <= 0) t += m;
    _state = t & m;
    return ((_state >> 7) ^ (_state >> 15) ^ (_state >> 22)) & 0xFF;
  }
}

List<int> _encode(String plain) {
  if (plain.isEmpty) return const <int>[];
  final raw = Uint8List.fromList(plain.codeUnits);
  final padLen = 3 + Random().nextInt(5); // 3..7 trailing zero bytes
  final padded = Uint8List(raw.length + padLen);
  for (var i = 0; i < raw.length; i++) {
    padded[i] = raw[i];
  }
  final stream = _Stream(_seedFromTokens());
  final out = Uint8List(padded.length);
  for (var i = 0; i < padded.length; i++) {
    out[i] = (padded[i] ^ stream.nextByte()) & 0xFF;
  }
  return out;
}

void _emit(String label, String plain) {
  final bytes = _encode(plain);
  print('// $label  →  ${plain.length} chars');
  print('const List<int> $label = <int>[');
  final lines = <String>[];
  var line = '  ';
  for (var i = 0; i < bytes.length; i++) {
    line += '0x${bytes[i].toRadixString(16).padLeft(2, '0')},';
    if ((i + 1) % 12 == 0) {
      lines.add(line);
      line = '  ';
    } else {
      line += ' ';
    }
  }
  if (line.trim().isNotEmpty) lines.add(line);
  print(lines.join('\n'));
  print('];\n');
}

void main() {
  // Fill these in once Firebase + AppsFlyer credentials are issued.
  // Each entry is emitted as an opaque byte list ready to paste into
  // the matching setup/*.dart file.
  final targets = <String, String>{
    // setup/endpoint_secrets.dart
    'kVerdictHost': 'https://chickennhop.com',
    'kVerdictPath': '/config.php',

    // setup/tracker_secrets.dart
    'kTrackerDevKey': 'hWF3hRzM89bQmSUTd3tJYb',
    'kFirebaseSender': '667813603421',
    'kGcdHost': 'https://gcdsdk.appsflyer.com',
    'kGcdPath': '/install_data/v4.0/',

    // core/agent_client.dart — UA fragments
    'kChromeRev': '131.0.0.0',
    'kWebKitRev': '537.36',
  };

  targets.forEach(_emit);
}
