import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../types/launch_mode.dart';

// ─────────────────────────────────────────────────────────────────────
// LOCAL VAULT — sticky data keyed under intentionally cryptic names
// ─────────────────────────────────────────────────────────────────────
// Backed by SharedPreferences. Sensitive values (resolved URL, one-shot
// push URL) are stored base64-encoded under short, unrecognisable keys
// so the prefs XML file does not advertise their meaning to anyone who
// dumps `/data/data/.../shared_prefs`.
//
// We do not depend on flutter_secure_storage: SharedPreferences is good
// enough for non-credential payloads, and removing the secure-storage
// plugin keeps the dependency surface and binary fingerprint smaller.
// ─────────────────────────────────────────────────────────────────────

class LocalVault {
  // Deliberately opaque short keys.
  static const _kMode = 'lv.m';
  static const _kResolvedUrl = 'lv.r';
  static const _kResolvedExpiry = 'lv.x';
  static const _kPushSnooze = 'lv.s';
  static const _kPushGranted = 'lv.g';
  static const _kPushOsBlocked = 'lv.b'; // OS-level dialog denied (no retry)
  static const _kPushColdUrl = 'lv.p';

  late SharedPreferences _prefs;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Launch mode ──────────────────────────────────────────────────
  LaunchMode readMode() => LaunchMode.parse(_prefs.getString(_kMode));

  Future<void> writeMode(LaunchMode mode) =>
      _prefs.setString(_kMode, mode.persistKey);

  // ── Resolved portal URL (base64-wrapped) ─────────────────────────
  String? readResolvedUrl() {
    final raw = _prefs.getString(_kResolvedUrl);
    if (raw == null || raw.isEmpty) return null;
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeResolvedUrl(String url) {
    return _prefs.setString(
      _kResolvedUrl,
      base64Encode(utf8.encode(url)),
    );
  }

  int? readResolvedExpiry() => _prefs.getInt(_kResolvedExpiry);

  Future<void> writeResolvedExpiry(int unix) =>
      _prefs.setInt(_kResolvedExpiry, unix);

  bool isResolvedExpired() {
    final exp = readResolvedExpiry();
    if (exp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= exp;
  }

  // ── Push permission state ────────────────────────────────────────
  bool isPushGranted() => _prefs.getBool(_kPushGranted) ?? false;

  Future<void> writePushGranted(bool granted) =>
      _prefs.setBool(_kPushGranted, granted);

  bool isPushOsBlocked() => _prefs.getBool(_kPushOsBlocked) ?? false;

  Future<void> markPushOsBlocked() =>
      _prefs.setBool(_kPushOsBlocked, true);

  int? readPushSnoozeUntil() => _prefs.getInt(_kPushSnooze);

  Future<void> writePushSnoozeUntil(int unix) =>
      _prefs.setInt(_kPushSnooze, unix);

  bool shouldShowPushPromo() {
    if (isPushGranted()) return false;
    if (isPushOsBlocked()) return false;
    final snooze = readPushSnoozeUntil();
    if (snooze == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= snooze;
  }

  // ── One-shot cold-start push URL ─────────────────────────────────
  String? _readColdPushUrl() {
    final raw = _prefs.getString(_kPushColdUrl);
    if (raw == null || raw.isEmpty) return null;
    try {
      return utf8.decode(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> stashColdPushUrl(String url) {
    return _prefs.setString(
      _kPushColdUrl,
      base64Encode(utf8.encode(url)),
    );
  }

  Future<String?> takeColdPushUrl() async {
    final url = _readColdPushUrl();
    if (url != null) await _prefs.remove(_kPushColdUrl);
    return url;
  }
}
