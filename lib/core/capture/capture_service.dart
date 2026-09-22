/// CaptureService — uploads raw audio / photo bytes to MAIC, which then
/// runs server-side transcription (Whisper for voice, Tesseract for
/// photo OCR) and writes the resulting note.
///
/// Per the phone-is-a-relay rule, the phone NEVER runs any local model —
/// no on-device STT, no on-device OCR. Bytes go up; transcripts come back
/// as a note the user can open in Tasks.
///
/// Endpoints (added by Phase 4C):
///   POST /v1/users/me/workspace/notes
///     multipart/form-data:
///       kind="voice_memo" or "photo_ocr"
///       file: [bytes]
///     response: NoteSummaryOut (new note)
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
  /// side and write a note with `{transcript, audio_deleted: true}` in
  /// the `request` subkey. The audio bytes do NOT persist in the
  /// workspace (per roadmap product rule: free tier would burn fast).
  Future<CaptureResult> uploadVoiceMemo(File audioFile) async {
    return _upload(
      kind: 'voice_memo',
      file: audioFile,
      filename: 'voice_memo.m4a',
      mimeType: 'audio/m4a',
    );
  }

  /// Upload a photo for OCR. MAIC runs Tesseract server-side and writes
  /// a note with `{ocr_text, image_deleted: true}` in `request`.
  Future<CaptureResult> uploadPhoto(File imageFile) async {
    return _upload(
      kind: 'photo_ocr',
      file: imageFile,
      filename: 'photo.jpg',
      mimeType: 'image/jpeg',
    );
  }

  Future<CaptureResult> _upload({
    required String kind,
    required File file,
    required String filename,
    required String mimeType,
  }) async {
    try {
      final form = FormData.fromMap({
        'kind': kind,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
        ),
      });
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/users/me/workspace/notes',
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
      // Backend returns a single NoteSummaryOut after creation. Convert.
      final note = NoteSummary(
        noteId: data['note_id']?.toString() ?? '',
        subkeys: ((data['subkeys'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        totalBytes: (data['total_bytes'] as num?)?.toInt() ?? 0,
        lastUpdatedAt: data['last_updated_at'] != null
            ? DateTime.tryParse(data['last_updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        lastUpdatedBy: data['last_updated_by']?.toString(),
        requestKind: data['request_kind']?.toString(),
      );
      return CaptureResult.ok(note);
    } on DioException catch (e) {
      // 401/403/429/etc all surface here. The auth classifier in the
      // Dio interceptor will have already attempted relogin for
      // recoverable cases; whatever survived is what we show.
      final status = e.response?.statusCode;
      final detail = (e.response?.data is Map)
          ? (e.response!.data['detail']?.toString() ?? '')
          : '';
      final msg = detail.isNotEmpty
          ? detail
          : 'Upload failed (${status ?? "no status"})';
      return CaptureResult.err(msg);
    } catch (e) {
      return CaptureResult.err('Upload failed: $e');
    }
  }
}
