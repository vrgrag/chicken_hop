import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────
// STRING ARMOR — opaque byte-stream cipher for secret literals
// ─────────────────────────────────────────────────────────────────────
// All sensitive constants (config endpoint, tracker key, push project)
// are stored as opaque integer lists and unwrapped at call time. The
// raw bytes are not greppable from the APK strings table.
//
// The keystream is produced by a tiny Park-Miller MINSTD32 PRNG seeded
// from a project-unique ASCII phrase. To rotate the binary fingerprint
// across projects, change `_seedTokens` and re-encode every protected
// constant with tool/seed_secrets.dart.
//
// Encoding algorithm (mirror of `unveil`, see tool/seed_secrets.dart):
//   1. Take UTF-8 bytes of plaintext.
//   2. Pad with a uniformly random tail length of 3..7 zero bytes (the
//      decoder strips trailing zero bytes), so identical inputs yield
//      different outputs across rebuilds.
//   3. For each byte, XOR with `keystream[i]` from the PRNG.
//   4. Emit the resulting list of ints.
// ─────────────────────────────────────────────────────────────────────

// Unique seed phrase for Chicken Hop. DO NOT reuse across projects.
// Concatenating the tokens reads as "chickenhop-roost", which keeps
// the seed memorable without ever appearing as a single string literal.
const List<String> _seedTokens = <String>[
  'chicken',
  '-',
  'hop',
  '-',
  'roost',
  '42',
];

int _seedFromTokens() {
  var hash = 0x811c9dc5; // FNV-1a 32-bit basis
  for (final token in _seedTokens) {
    for (final code in token.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
  }
  // Guarantee a non-zero seed (Park-Miller is undefined at 0).
  if (hash == 0) hash = 1;
  return hash & 0x7FFFFFFF;
}

class _MinstdStream {
  int _state;
  _MinstdStream(int seed) : _state = seed == 0 ? 1 : (seed & 0x7FFFFFFF);

  int nextByte() {
    // Schrage's algorithm for 31-bit Park-Miller. Pure Dart, no `int`
    // overflow on 64-bit VMs and no double precision pitfalls on web.
    const a = 48271;
    const m = 0x7FFFFFFF;
    const q = m ~/ a;
    const r = m % a;
    final hi = _state ~/ q;
    final lo = _state % q;
    var t = a * lo - r * hi;
    if (t <= 0) t += m;
    _state = t & m;
    // Mix bits to avoid low-entropy LSB stripes when XOR-ing ASCII text.
    final mixed = ((_state >> 7) ^ (_state >> 15) ^ (_state >> 22)) & 0xFF;
    return mixed;
  }
}

/// Decodes an opaque byte list produced by `seed_secrets.dart` back into
/// the original UTF-8 string. Returns an empty string for an empty input.
String unveil(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final stream = _MinstdStream(_seedFromTokens());
  final out = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ stream.nextByte()) & 0xFF;
  }
  // Strip trailing zero pad bytes (see encoder).
  var end = out.length;
  while (end > 0 && out[end - 1] == 0) {
    end--;
  }
  return String.fromCharCodes(out.sublist(0, end));
}

/// Re-export used by the encoder utility so the same PRNG implementation
/// drives both sides without duplication.
@visibleForBuildScripts
int debugSeedValue() => _seedFromTokens();

@visibleForBuildScripts
int debugNextStreamByte(int state) {
  // Mirror MinstdStream.nextByte for the build-time tool.
  const a = 48271;
  const m = 0x7FFFFFFF;
  const q = m ~/ a;
  const r = m % a;
  final hi = state ~/ q;
  final lo = state % q;
  var t = a * lo - r * hi;
  if (t <= 0) t += m;
  final newState = t & m;
  final mixed = ((newState >> 7) ^ (newState >> 15) ^ (newState >> 22)) & 0xFF;
  return (newState << 8) | mixed;
}

/// Marker annotation — meaningless at runtime; used by the encoder tool
/// to filter out helpers that must not be tree-shaken.
class _BuildScriptOnly {
  const _BuildScriptOnly();
}

const visibleForBuildScripts = _BuildScriptOnly();
