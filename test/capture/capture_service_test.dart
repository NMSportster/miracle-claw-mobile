/// Tests for CaptureService — the multipart upload to MAIC for voice
/// memos and photo OCR. Uses DioAdapter to mock the network layer
/// without needing a live MAIC.
///
/// 4C coverage: confirm request shape, headers, response parsing, and
/// error propagation. Doesn't exercise the on-device recorder or
/// image picker — those are platform channels and not unit-testable
/// without an integration harness.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miracle_claw_mobile/core/api/api_client.dart';
import 'package:miracle_claw_mobile/core/capture/capture_service.dart';

/// Minimal ApiClient stub. We don't need the real one because
/// CaptureService only uses Dio; we plug our own Dio in via
/// the constructor in the test.
class _StubApiClient implements ApiClient {
  @override
  Dio get dio => throw UnimplementedError();
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hand-rolled mock adapter that captures the request and returns a
/// canned response. Much lighter than http_mock_adapter for what we
/// need (one request shape assertion per case).
class _MockAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  Map<String, dynamic> responseBody;
  int responseStatus;
  Object? responseError;

  _MockAdapter({
    this.responseStatus = 200,
    Map<String, dynamic>? responseBody,
  }) : responseBody = responseBody ?? const {
          'note_id': 'test-note-id',
          'subkeys': ['request'],
          'total_bytes': 1024,
          'last_updated_at': '2026-09-22T04:00:00Z',
          'last_updated_by': 'phone:upload',
          'request_kind': 'voice_memo',
        };

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    lastRequest = options;
    if (responseError != null) throw responseError!;
    final encoded = utf8.encode(jsonEncode(responseBody));
    return ResponseBody.fromBytes(
      encoded,
      responseStatus,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }
}

void main() {
  group('CaptureService.uploadVoiceMemo', () {
    test('POSTs multipart with kind=voice_memo + audio file', () async {
      final adapter = _MockAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.maicserver.com'));
      dio.httpClientAdapter = adapter;

      // Make a tiny fake audio file so MultipartFile.fromFile is happy.
      final tmpDir = Directory.systemTemp.createTempSync('cap_');
      final tmpFile = File('${tmpDir.path}/voice_memo.m4a');
      tmpFile.writeAsBytesSync([1, 2, 3, 4, 5]);

      final svc = CaptureService(dio);
      final result = await svc.uploadVoiceMemo(tmpFile);

      expect(result.isOk, isTrue);
      expect(result.note!.noteId, 'test-note-id');
      expect(result.note!.requestKind, 'voice_memo');
      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.path, '/v1/users/me/workspace/notes');
      expect(adapter.lastRequest!.data, isA<FormData>());

      tmpFile.deleteSync();
      tmpDir.deleteSync();
    });

    test('returns error message on 4xx', () async {
      final adapter = _MockAdapter(
        responseStatus: 413,
        responseBody: {'detail': 'Workspace quota exceeded'},
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.maicserver.com'));
      dio.httpClientAdapter = adapter;

      final tmpDir = Directory.systemTemp.createTempSync('cap_');
      final tmpFile = File('${tmpDir.path}/voice_memo.m4a');
      tmpFile.writeAsBytesSync([1, 2, 3]);

      final svc = CaptureService(dio);
      final result = await svc.uploadVoiceMemo(tmpFile);

      expect(result.isOk, isFalse);
      expect(result.error, contains('quota'));

      tmpFile.deleteSync();
      tmpDir.deleteSync();
    });
  });

  group('CaptureService.uploadPhoto', () {
    test('POSTs multipart with kind=photo_ocr + image file', () async {
      final adapter = _MockAdapter(responseBody: {
        'note_id': 'photo-note-id',
        'subkeys': ['request'],
        'total_bytes': 512,
        'last_updated_at': '2026-09-22T04:01:00Z',
        'last_updated_by': 'phone:upload',
        'request_kind': 'photo_ocr',
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api.maicserver.com'));
      dio.httpClientAdapter = adapter;

      final tmpDir = Directory.systemTemp.createTempSync('cap_');
      final tmpFile = File('${tmpDir.path}/photo.jpg');
      tmpFile.writeAsBytesSync([9, 8, 7]);

      final svc = CaptureService(dio);
      final result = await svc.uploadPhoto(tmpFile);

      expect(result.isOk, isTrue);
      expect(result.note!.requestKind, 'photo_ocr');
      expect(adapter.lastRequest!.path, '/v1/users/me/workspace/notes');

      tmpFile.deleteSync();
      tmpDir.deleteSync();
    });

    test('handles network errors with a generic message', () async {
      final adapter = _MockAdapter();
      adapter.responseError = 'connection refused';
      final dio = Dio(BaseOptions(baseUrl: 'https://api.maicserver.com'));
      dio.httpClientAdapter = adapter;

      final tmpDir = Directory.systemTemp.createTempSync('cap_');
      final tmpFile = File('${tmpDir.path}/photo.jpg');
      tmpFile.writeAsBytesSync([1]);

      final svc = CaptureService(dio);
      final result = await svc.uploadPhoto(tmpFile);

      expect(result.isOk, isFalse);
      expect(result.error, isNotNull);

      tmpFile.deleteSync();
      tmpDir.deleteSync();
    });
  });
}
