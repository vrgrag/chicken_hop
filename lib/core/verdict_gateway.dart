import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

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
      debugPrint('[VerdictGateway] endpoint is EMPTY — check endpoint_secrets');
      return VerdictPayload.unreachable('endpoint unset');
    }

    debugPrint('[VerdictGateway] POST $endpoint');
    if (kDebugMode) {
      debugPrint('[VerdictGateway] request body: ${jsonEncode(body)}');
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

      debugPrint('[VerdictGateway] response ${reply.statusCode}: ${reply.body}');

      // Try to parse the body regardless of status code: some backends
      // return 4xx with a valid JSON verdict (e.g. 404 + {"ok":true,"url":...}).
      final parsed = _tryParse(reply.body);

      if (parsed != null) {
        final verdict = VerdictPayload.fromMap(parsed);
        debugPrint('[VerdictGateway] parsed verdict accepted=${verdict.accepted}'
            ' destination=${verdict.destination}');
        if (reply.statusCode != 200 && !verdict.accepted) {
          debugPrint('[VerdictGateway] non-200 + not accepted'
              ' → unreachable (server: ${reply.statusCode})');
          return VerdictPayload.unreachable('http ${reply.statusCode}');
        }
        if (verdict.accepted && verdict.destination != null) {
          await _vault.writeResolvedUrl(verdict.destination!);
          final exp = verdict.freshUntil;
          if (exp != null) await _vault.writeResolvedExpiry(exp);
        }
        return verdict;
      }

      if (reply.statusCode != 200) {
        debugPrint('[VerdictGateway] non-200 and no parseable JSON → unreachable');
        return VerdictPayload.unreachable('http ${reply.statusCode}');
      }

      debugPrint('[VerdictGateway] body is not a Map → unreachable');
      return VerdictPayload.unreachable('invalid body');
    } on TimeoutException {
      debugPrint('[VerdictGateway] request timed out after'
          ' ${AppFacade.verdictTimeoutSeconds}s');
      return VerdictPayload.unreachable('timeout');
    } catch (e, st) {
      debugPrint('[VerdictGateway] ERROR: $e\n$st');
      return VerdictPayload.unreachable(e.toString());
    }
  }

  // ── helpers ──────────────────────────────────────────────────────

  Map<String, dynamic>? _tryParse(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    } catch (_) {}
    return null;
  }
}
