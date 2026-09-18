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

    Future<void> pump() async {
      while (!controller.isClosed) {
        try {
          if (!sseFailed) {
            await _pumpSse(controller, lastSeen);
          } else {
            await _pumpPoll(controller, lastSeen);
            // After a few successful polls, try SSE again.
            sseFailed = false;
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
          }
          if (!sseFailed) {
            sseFailed = true;
            // Will fall through to poll on next iteration.
          }
        }
      }
    }

    controller.onListen = pump;
    controller.onCancel = () {
      // No-op; pump() will see isClosed and exit.
    };
    return controller.stream;
  }

  Future<void> _pumpSse(
    StreamController<WorkspaceEvent> controller,
    List<int> lastSeen,
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
        // No overall timeout — SSE is long-lived.
        receiveTimeout: Duration.zero,
      ),
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
    while (!controller.isClosed) {
      try {
        // See listNotes() for why this is <dynamic>, not <List<dynamic>>.
        final r = await _dio.get<dynamic>(
          '/v1/users/me/workspace/poll',
          queryParameters: {
            'since_event_id': lastSeen[0],
            'timeout_seconds': 30,
          },
        );
        if (r.statusCode == 204) {
          // Timeout — no events. Loop and try again.
          continue;
        }
        _checkStatus(r);
        final data = r.data;
        if (data is! List) {
          // Non-list body — don't crash; back off briefly and loop.
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        for (final raw in data.cast<Map<String, dynamic>>()) {
          if (controller.isClosed) break;
          final ev = WorkspaceEvent.fromJson(raw);
          lastSeen[0] = ev.eventId;
          controller.add(ev);
        }
      } on DioException catch (e) {
        // Rate limit / transient — back off briefly, then retry.
        if (e.response?.statusCode == 429) {
          await Future.delayed(const Duration(seconds: 5));
        } else {
          await Future.delayed(const Duration(seconds: 1));
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


class WorkspaceException implements Exception {
  WorkspaceException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'WorkspaceException($statusCode): $message';
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
