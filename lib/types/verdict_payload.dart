/// Reply from the verdict endpoint.
///
/// `accepted` true + non-null [destination] routes the user to the
/// portal stage. Any other shape falls back to the local puzzle.
class VerdictPayload {
  final bool accepted;
  final String? destination;
  final int? freshUntil;
  final String? notice;

  const VerdictPayload({
    required this.accepted,
    this.destination,
    this.freshUntil,
    this.notice,
  });

  factory VerdictPayload.fromMap(Map<String, dynamic> map) {
    return VerdictPayload(
      accepted: (map['ok'] as bool?) ?? false,
      destination: map['url'] as String?,
      freshUntil: map['expires'] as int?,
      notice: map['message'] as String?,
    );
  }

  factory VerdictPayload.unreachable(String reason) =>
      VerdictPayload(accepted: false, notice: reason);

  bool get isStillFresh {
    final stamp = freshUntil;
    if (stamp == null) return true; // no expiry → always fresh
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now < stamp;
  }
}
