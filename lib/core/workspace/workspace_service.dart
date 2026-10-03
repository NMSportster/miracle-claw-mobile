/// WorkspaceService — REST + change-feed client for the MAIC per-user
/// workspace endpoints.
///
/// Spec: memory/projects/workspace_architecture.md
/// MAIC backend: api/routes/workspace.py
///
/// Two responsibilities:
///   1. REST: list/get/put/delete notes, fetch quota. Uses the shared
///      Dio instance from ApiClient (so JWT injection + pairing
///      interceptor still apply — though we won't be paired anymore).
///   2. Change feed: subscribe to note create/update/delete events
///      via SSE (preferred) or long-poll (fallback). Used by the UI
///      to refresh lists/details when the desktop writes back.
///
/// On the phone, this service is the only way to talk to MAIC's
/// workspace. It replaces the old pairing transport for the
/// phone→desktop message bus.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../pairing/device_id_store.dart';
import '../pairing/pairing_service.dart' show deviceIdStoreProvider;
import 'note_model.dart';

/// Provider for the singleton WorkspaceService, injected with the shared
/// Dio client + device_id store (for X-Miracle-Device-Id audit header).
final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  final client = ref.watch(apiClientProvider);
  final deviceStore = ref.watch(deviceIdStoreProvider);
  return WorkspaceService(client.dio, deviceStore);
});

/// REST + change-feed client. Holds no state itself — callers cache via
/// Riverpod providers. All methods return futures; the SSE method returns
/// a broadcast Stream the caller can subscribe to.
class WorkspaceService {
  WorkspaceService(this._dio, this._deviceStore);

  final Dio _dio;
  final DeviceIdStore _deviceStore;

  // ───────────────────────────────────────────────────────────────
  // REST
  // ───────────────────────────────────────────────────────────────

  /// `GET /v1/users/me/workspace/quota` → tier + bytes used + remaining.
  Future<WorkspaceQuota> fetchQuota() async {
    final r = await _dio.get<Map<String, dynamic>>('/v1/users/me/workspace/quota');
    _checkStatus(r);
    return WorkspaceQuota.fromJson(r.data!);
  }

  /// `GET /v1/users/me/workspace` → list note summaries (newest first).
  Future<List<NoteSummary>> listNotes({int limit = 50, int offset = 0}) async {
    // Use <dynamic>, not <List<dynamic>> — Dio's generic is an implicit
    // cast on response construction, and if MAIC returns a non-list body
    // (e.g. an error envelope on 429) the cast throws DioException
    // (type=unknown, status=0), masking the real status code. With
    // <dynamic> we let Dio parse loose, then safely cast here.
    final r = await _dio.get<dynamic>(
      '/v1/users/me/workspace',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    _checkStatus(r);
    final data = r.data;
    if (data is! List) {
      throw WorkspaceException(r.statusCode ?? 0,
          'expected list, got ${data.runtimeType}');
    }
    return data
        .cast<Map<String, dynamic>>()
        .map(NoteSummary.fromJson)
        .toList(growable: false);
  }

  /// `GET /v1/users/me/workspace/notes/{id}` → all subkeys for one note.
  Future<NoteDetail> fetchNote(String noteId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/workspace/notes/$noteId',
    );
    _checkStatus(r);
    return NoteDetail.fromJson(r.data!);
  }

  /// `PUT /v1/users/me/workspace/notes/{id}/{subkey}` → upsert one subkey.
  /// Version increments on the server side. Throws [WorkspaceQuotaException]
  /// if the new value would exceed the user's quota.
  Future<WriteAck> writeSubkey({
    required String noteId,
    required String subkey,
    required Map<String, dynamic> value,
  }) async {
    try {
      final r = await _dio.put<Map<String, dynamic>>(
        '/v1/users/me/workspace/notes/$noteId/$subkey',
        data: value,
        options: Options(headers: await _auditHeaders()),
      );
      _checkStatus(r);
      return WriteAck.fromJson(r.data!);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// `PUT /v1/users/me/workspace/notes/{id}` → batch write. Returns
  /// one WriteAck per subkey written.
  Future<List<WriteAck>> writeNoteBatch({
    required String noteId,
    required Map<String, Map<String, dynamic>> subkeys,
  }) async {
    try {
      final r = await _dio.put<List<dynamic>>(
        '/v1/users/me/workspace/notes/$noteId',
        data: {
          'subkeys': subkeys,
        },
        options: Options(headers: await _auditHeaders()),
      );
      _checkStatus(r);
      return r.data!
          .cast<Map<String, dynamic>>()
          .map(WriteAck.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// `DELETE /v1/users/me/workspace/notes/{id}` → cascade delete. 204 on
  /// success; 404 if the note doesn't exist.
  Future<void> deleteNote(String noteId) async {
    final r = await _dio.delete<void>(
      '/v1/users/me/workspace/notes/$noteId',
      options: Options(headers: await _auditHeaders()),
    );
    _checkStatus(r);
  }

  // ───────────────────────────────────────────────────────────────
  // Change feed: SSE (preferred) + long-poll (fallback)
  // ───────────────────────────────────────────────────────────────

  /// Subscribe to workspace events. Prefers SSE, falls back to long-poll
  /// if SSE fails. Returns a broadcast Stream so multiple listeners
  /// (list screen, detail screen) can share one connection.
  ///
  /// Pass `sinceEventId` to resume after a reconnect. The service
  /// tracks the last seen event id internally for auto-resume on
  /// transient errors.
  Stream<WorkspaceEvent> events({int sinceEventId = 0}) {
    // Use a StreamController so we can retry on SSE failure with poll
    // as fallback. Multiple listeners share via broadcast.
    final controller = StreamController<WorkspaceEvent>.broadcast();
    final lastSeen = <int>[sinceEventId];
    var sseFailed = false;
    // CancelToken held by the active pump so onCancel can tear the
    // SSE connection down promptly (Dio 5 + Cloudflare HTTP/2 keep
    // streams open on Android even when no consumer is listening).
    CancelToken? sseCancelToken;

    Future<void> pump() async {
      var pumpIter = 0;
      while (!controller.isClosed) {
        pumpIter++;
        try {
          if (!sseFailed) {
            // ignore: avoid_print
            print('[DBG-WS] pump iter=$pumpIter trying SSE');
            final ct = CancelToken();
            sseCancelToken = ct;
            try {
              // Watchdog: if the SSE doesn't produce any chunk within
              // [sseWatchdogTimeout], cancel the request and fall back
              // to poll. Without this, Dio 5 + the Cloudflare HTTP/2
              // tunnel will hold the connection open past receiveTimeout
              // and we'll leak streams (observed: 70+ open streams in
              // 90 seconds, hammering CF rate limit).
              await _pumpSseWithWatchdog(controller, lastSeen, ct);
              // ignore: avoid_print
              print('[DBG-WS] pump iter=$pumpIter SSE returned cleanly');
            } finally {
              sseCancelToken = null;
            }
          } else {
            // ignore: avoid_print
            print('[DBG-WS] pump iter=$pumpIter using POLL (sseFailed=true)');
            await _pumpPoll(controller, lastSeen);
            // After a few successful polls, try SSE again.
            sseFailed = false;
          }
        } catch (e) {
          // ignore: avoid_print
          print('[DBG-WS] pump iter=$pumpIter error: $e');
          if (!controller.isClosed) {
            controller.addError(e);
          }
          if (!sseFailed) {
            sseFailed = true;
            // Will fall through to poll on next iteration.
          }
          // Brief backoff before the next attempt — otherwise the
          // pump can spin as fast as Dio lets us open sockets, which
          // is what produced 70+ open streams in 90 seconds in the
          // 2026-10-03 incident. 2s is short enough that the user
          // doesn't feel it, long enough that we can't drown MAIC.
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    controller.onListen = pump;
    controller.onCancel = () {
      // Cancel any in-flight SSE so the underlying HTTP/2 stream is
      // torn down. Without this, the pump's `await for` keeps
      // listening until the next disconnect, which Dio on Android
      // ties to the eventual TCP teardown (minutes, sometimes never).
      final ct = sseCancelToken;
      if (ct != null && !ct.isCancelled) {
        ct.cancel('Stream cancelled by listener');
      }
      // No-op; pump() will see isClosed and exit.
    };
    return controller.stream;
  }

  /// Hard upper bound on how long an SSE connection may stay open
  /// without delivering a *full event* (a parsed `note.*` event, not
  /// a keepalive comment). Set to 45s so it's longer than the typical
  /// `keepaliveTimeout` of 15s + data, but short enough that a stuck
  /// stream can't accumulate. Matches MAIC's `{'event': 'timeout'}`
  /// push cadence (30s) plus slack.
  static const Duration _sseWatchdogTimeout = Duration(seconds: 45);

  /// Same as [_pumpSse] but cancels the request via [cancelToken] if
  /// no event arrives within [_sseWatchdogTimeout]. The original
  /// request still has Dio-level timeouts (10s connect, 20s receive)
  /// — this watchdog is the safety net for the case where those don't
  /// fire (observed on Dio 5.7 + Cloudflare HTTP/2 tunnel on
  /// Samsung Android 10).
  Future<void> _pumpSseWithWatchdog(
    StreamController<WorkspaceEvent> controller,
    List<int> lastSeen,
    CancelToken cancelToken,
  ) async {
    final sseFuture = _pumpSse(controller, lastSeen, cancelToken);
    final watchdog = Future<void>.delayed(_sseWatchdogTimeout, () {
      throw _SseWatchdogTimeout();
    });
    try {
      await Future.any([sseFuture, watchdog]);
    } catch (e) {
      // Cancel the in-flight HTTP/2 stream so the socket is released.
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('SSE watchdog timeout after $_sseWatchdogTimeout');
      }
      // Wait briefly for the original future to unwind so we don't
      // race its teardown with the next pump iteration.
      try { await sseFuture; } catch (_) {}
      rethrow;
    }
  }

  Future<void> _pumpSse(
    StreamController<WorkspaceEvent> controller,
    List<int> lastSeen,
    CancelToken cancelToken,
  ) async {
    final response = await _dio.get<ResponseBody>(
      '/v1/users/me/workspace/stream',
      queryParameters: {
        if (lastSeen[0] > 0) 'since_event_id': lastSeen[0],
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
        },
        // SSE responses are 200 only.
        validateStatus: (s) => s != null && s < 400,
        // Override the global ApiClient timeouts so SSE doesn't hang
        // forever on Android (Dio + Cloudflare HTTP/2 tunnel has a
        // known issue where the connection stays open without parsed
        // data). 20s is generous: if no chunk in 20s, abandon and
        // let pump()'s catch switch to the poll fallback.
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
      ),
      cancelToken: cancelToken,
    );

    if (response.statusCode != 200 || response.data == null) {
      throw WorkspaceException(response.statusCode ?? 0, 'SSE stream failed');
    }

    final lineStream = response.data!.stream
        .map((chunk) => utf8.decode(chunk, allowMalformed: true))
        .transform(const LineSplitter());

    String? eventName;
    final dataLines = <String>[];
    final idLines = <String>[];

    await for (final line in lineStream) {
      if (controller.isClosed) break;
      if (line.isEmpty) {
        // Dispatch
        if (dataLines.isNotEmpty) {
          final raw = dataLines.join('\n');
          try {
            final json = jsonDecode(raw) as Map<String, dynamic>;
            if (eventName == 'note.created' ||
                eventName == 'note.updated' ||
                eventName == 'note.deleted') {
              final ev = WorkspaceEvent.fromJson(json);
              lastSeen[0] = ev.eventId;
              controller.add(ev);
            }
            // 'hello' / 'keepalive' / 'timeout' / 'error' are ignored.
          } catch (_) {
            // Bad JSON in stream — skip but don't kill the pump.
          }
        }
        eventName = null;
        dataLines.clear();
        idLines.clear();
        continue;
      }
      if (line.startsWith(':')) continue;  // comment / keepalive
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      } else if (line.startsWith('id:')) {
        idLines.add(line.substring(3).trim());
      }
    }
  }

  Future<void> _pumpPoll(
    StreamController<WorkspaceEvent> controller,
    List<int> lastSeen,
  ) async {
    // Baseline idle interval between polls when nothing is happening.
    // We don't want to hammer MAIC when the user is doing nothing.
    const idlePollInterval = Duration(seconds: 3);
    while (!controller.isClosed) {
      try {
        // See listNotes() for why this is <dynamic>, not <List<dynamic>>.
        final r = await _dio.get<dynamic>(
          '/v1/users/me/workspace/poll',
          queryParameters: {
            'since_event_id': lastSeen[0],
            'timeout_seconds': 25,
          },
        );
        if (controller.isClosed) break;
        if (r.statusCode == 204) {
          // No events — server-side long-poll timed out. Always sleep
          // before retrying; the previous version did an immediate
          // continue which, combined with SSE hanging on Android, drove
          // MAIC's CF rate limit into the floor (~3 req/s sustained).
          await Future.delayed(idlePollInterval);
          continue;
        }
        _checkStatus(r);
        final data = r.data;
        if (data is! List) {
          // Non-list body — don't crash; back off briefly and loop.
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        // Got events — process them then resume the idle cadence.
        for (final raw in data.cast<Map<String, dynamic>>()) {
          if (controller.isClosed) break;
          final ev = WorkspaceEvent.fromJson(raw);
          lastSeen[0] = ev.eventId;
          controller.add(ev);
        }
        await Future.delayed(idlePollInterval);
      } on DioException catch (e) {
        // Rate limit / transient — back off briefly, then re-throw so
        // the outer pump() loop can mark sseFailed and switch paths.
        if (e.response?.statusCode == 429) {
          await Future.delayed(const Duration(seconds: 30));
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
        throw _translate(e);
      }
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────

  Future<Map<String, String>> _auditHeaders() async {
    final deviceId = await _deviceStore.ensure();
    return {
      'X-Miracle-Device-Id': 'phone:$deviceId',
    };
  }

  void _checkStatus(Response<dynamic> r) {
    if (r.statusCode == null || r.statusCode! >= 400) {
      throw WorkspaceException(r.statusCode ?? 0, r.statusMessage ?? 'HTTP ${r.statusCode}');
    }
  }

  /// Translate a DioException into either a WorkspaceException or a
  /// WorkspaceQuotaException. The latter carries the headers we need
  /// for a quota-exceeded UI flow.
  Exception _translate(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final body = e.response?.data;
    if (status == 413 && body is Map && body['detail'] is Map) {
      final detail = body['detail'] as Map;
      if (detail['error'] == 'workspace_quota_exceeded') {
        return WorkspaceQuotaException(
          tier: detail['tier'] as String? ?? 'unknown',
          quotaBytes: (detail['quota_bytes'] as num?)?.toInt() ?? 0,
          usedBytes: (detail['used_bytes'] as num?)?.toInt() ?? 0,
          requestedBytes: (detail['requested_bytes'] as num?)?.toInt() ?? 0,
        );
      }
    }
    if (status == 413) {
      // Generic 413 — single-value too large, etc.
      return WorkspaceException(413, e.message ?? 'value too large');
    }
    return WorkspaceException(status, e.message ?? 'request failed');
  }
}

// ─────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────


/// Thrown by [_pumpSseWithWatchdog] when no SSE chunk arrives within
/// [_sseWatchdogTimeout]. Distinct from [WorkspaceException] so the
/// pump loop can log it cleanly without it being treated as a regular
/// HTTP failure. Always catches in the outer pump() and switches to
/// the poll fallback.
class _SseWatchdogTimeout implements Exception {
  @override
  String toString() => 'SSE watchdog timeout (no data for 45s)';
}

class WorkspaceException implements Exception {
  WorkspaceException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'WorkspaceException($statusCode): $message';

  /// User-facing message. Prefer this in the UI over [toString].
  ///
  /// Before this, screens showed e.g. "Failed to load:
  /// WorkspaceException(429): Too Many Requests" — accurate, but
  /// leaked the exception class name and the raw HTTP status. Now we
  /// produce a short, friendly line; fall back to the server message
  /// for anything we don't recognise.
  String get userMessage {
    switch (statusCode) {
      case 429:
        return 'You\'re doing that too fast. Try again in a minute.';
      case 503:
      case 502:
      case 504:
        return 'Server temporarily unavailable. Try again shortly.';
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'You don\'t have access to that task.';
      case 404:
        return 'That task no longer exists.';
      case 413:
        return 'Your workspace is full.';
      case 500:
        return 'Server error. Try again or check back later.';
      default:
        if (statusCode >= 500) return 'Server error ($statusCode).';
        if (statusCode >= 400) return 'Request rejected ($statusCode).';
        return message;
    }
  }
}

/// Thrown when a write would exceed the user's tier quota. Carries the
/// numbers so the UI can show "out of space, upgrade?" with confidence.
class WorkspaceQuotaException extends WorkspaceException {
  WorkspaceQuotaException({
    required this.tier,
    required this.quotaBytes,
    required this.usedBytes,
    required this.requestedBytes,
  }) : super(413, 'workspace quota exceeded');

  final String tier;
  final int quotaBytes;
  final int usedBytes;
  final int requestedBytes;

  int get remainingBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  @override
  String toString() =>
      'WorkspaceQuotaException(tier=$tier, used=$usedBytes, quota=$quotaBytes, requested=$requestedBytes)';
}
