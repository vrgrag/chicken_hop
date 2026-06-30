import 'dart:async';
import 'dart:convert';

import '../setup/app_facade.dart';
import '../types/verdict_payload.dart';
import 'agent_client.dart';
import 'local_vault.dart';

// ─────────────────────────────────────────────────────────────────────
// VERDICT GATEWAY — POST the attribution body, parse the reply
// ─────────────────────────────────────────────────────────────────────
// Returned `VerdictPayload` carries `accepted` + optional `destination`.
// Successful payloads are persisted to LocalVault so a returning user
// can resume into the portal even if the back end is unreachable on
// the next launch.
// ─────────────────────────────────────────────────────────────────────

class VerdictGateway {
  final LocalVault _vault;

  VerdictGateway(this._vault);

  Future<VerdictPayload> consult(Map<String, dynamic> body) async {
    final endpoint = AppFacade.verdictEndpoint;
    if (endpoint.isEmpty) {
      return VerdictPayload.unreachable('endpoint unset');
    }

    try {
      final reply = await agent
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: AppFacade.verdictTimeoutSeconds),
          );

      if (reply.statusCode != 200) {
        return VerdictPayload.unreachable('http ${reply.statusCode}');
      }

      final parsed = jsonDecode(reply.body);
      if (parsed is! Map) {
        return VerdictPayload.unreachable('invalid body');
      }

      final verdict = VerdictPayload.fromMap(
        Map<String, dynamic>.from(parsed),
      );

      if (verdict.accepted && verdict.destination != null) {
        await _vault.writeResolvedUrl(verdict.destination!);
        final exp = verdict.freshUntil;
        if (exp != null) await _vault.writeResolvedExpiry(exp);
      }
      return verdict;
    } on TimeoutException {
      return VerdictPayload.unreachable('timeout');
    } catch (e) {
      return VerdictPayload.unreachable(e.toString());
    }
  }
}
