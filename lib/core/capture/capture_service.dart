/// CaptureService — uploads raw audio / photo bytes to MAIC, which then
/// runs server-side transcription (Whisper for voice, Tesseract for
/// photo OCR) and writes the resulting note.
///
/// Per the phone-is-a-relay rule, the phone NEVER runs any local model —
/// no on-device STT, no on-device OCR. Bytes go up; transcripts come back
/// as a note the user can open in Tasks.
///
/// Endpoints (added by Phase 4C):
///   POST /v1/users/me/workspace/notes/voice  multipart with 'audio' field
///   POST /v1/users/me/workspace/notes/photo  multipart with 'image' field
///   Each writes a kind={voice_memo|photo_ocr} note with the result in
///   the 'result' subkey. Raw bytes are NOT persisted.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../workspace/note_model.dart';

/// Provider for the singleton CaptureService, injected with the shared
/// Dio client (so JWT injection + 401-retry still apply).
final captureServiceProvider = Provider<CaptureService>((ref) {
  final client = ref.watch(apiClientProvider);
  return CaptureService(client.dio);
});

/// Result of an upload. We surface either a successful note (server
/// transcribed and stored) or a structured error.
class CaptureResult {
  CaptureResult.ok(this.note) : error = null;
  CaptureResult.err(this.error) : note = null;
  final NoteSummary? note;
  final String? error;

  bool get isOk => note != null;
}

class CaptureService {
  CaptureService(this._dio);
  final Dio _dio;

  /// Upload a voice memo audio file. MAIC will run Whisper on it server-
  /// side and write a note with the transcript in the `result` subkey.
  /// The audio bytes do NOT persist in the workspace.
  ///
  /// 2026-09-29: endpoint is /notes/voice (not /notes) — server has two
  /// dedicated routes, one per kind, gated by separate env flags. The
  /// response is the WriteAck of the 'result' subkey, not a NoteSummary.
  Future<CaptureResult> uploadVoiceMemo(File audioFile) async {
    return _upload(
      endpoint: '/v1/users/me/workspace/notes/voice',
      file: audioFile,
      filename: 'voice_memo.m4a',
      mimeType: 'audio/m4a',
      fieldName: 'audio',
    );
  }

  /// Upload a photo for OCR. MAIC runs Tesseract server-side and writes
  /// a note with the OCR text in the `result` subkey.
  Future<CaptureResult> uploadPhoto(File imageFile) async {
    return _upload(
      endpoint: '/v1/users/me/workspace/notes/photo',
      file: imageFile,
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
      fieldName: 'image',
    );
  }

  Future<CaptureResult> _upload({
    required String endpoint,
    required File file,
    required String filename,
    required String mimeType,
    required String fieldName,
  }) async {
    try {
      final form = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          file.path,
          filename: filename,
        ),
      });
      final r = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          // Generous timeout: audio transcription is 5-15s on Hetzner
          // CPU; photo OCR is <2s. Allow 60s to cover cold start.
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final data = r.data;
      if (data == null) {
        return CaptureResult.err('Empty response from server');
      }
      // Backend returns WriteAck: {note_id, subkey, size_bytes, version, updated_at}
      final noteId = data['note_id']?.toString() ?? '';
      if (noteId.isEmpty) {
        return CaptureResult.err('Missing note_id in response');
      }
      // The new note has exactly one subkey ('result'). Synthesize a
      // NoteSummary so the existing UI flows (refresh list, navigate)
      // work without further plumbing.
      final note = NoteSummary(
        noteId: noteId,
        subkeys: const ['result'],
        totalBytes: (data['size_bytes'] as num?)?.toInt() ?? 0,
        lastUpdatedAt: data['updated_at'] != null
            ? DateTime.tryParse(data['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        lastUpdatedBy: 'phone:capture',
        requestKind: endpoint.endsWith('/voice')
            ? 'voice_memo'
            : (endpoint.endsWith('/photo') ? 'photo_ocr' : null),
      );
      return CaptureResult.ok(note);
    } on DioException catch (e) {
      // 401/403/429/etc all surface here. The auth classifier in the
      // Dio interceptor will have already attempted relogin for
      // recoverable cases; whatever survived is what we show.
      final status = e.response?.statusCode;
      String detail = '';
      final d = e.response?.data;
      if (d is Map) {
        final det = d['detail'];
        if (det is String) {
          detail = det;
        } else if (det is Map && det['error'] != null) {
          // Our capture endpoints use {detail: {error: "...", feature: "..."}}
          detail = '${det['error']} (${det['feature']})';
        }
      }
      final msg = detail.isNotEmpty
          ? detail
          : 'Upload failed (${status ?? "no status"})';
      return CaptureResult.err(msg);
    } catch (e) {
      return CaptureResult.err('Upload failed: $e');
    }
  }
}
