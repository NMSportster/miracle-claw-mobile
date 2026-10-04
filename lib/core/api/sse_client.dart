import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Server-Sent Events parser for MAIC's streaming /v1/chat/completions.
///
/// MAIC returns SSE with `data: {...}\n\n` framing, OpenAI-compatible.
/// Each chunk is a partial `chat.completion.chunk` with delta content.

/// High-level wrapper: POST /v1/chat/completions with stream=true,
/// return a stream of content deltas.
Stream<String> streamChatCompletion({
  required Dio dio,
  required String model,
  required List<Map<String, String>> messages,
  double? temperature,
  int? maxTokens,
}) async* {
  final response = await dio.post<ResponseBody>(
    '/v1/chat/completions',
    data: {
      'model': model,
      'messages': messages,
      if (temperature != null) 'temperature': temperature,
      if (maxTokens != null) 'max_tokens': maxTokens,
      'stream': true,
    },
    options: Options(
      responseType: ResponseType.stream,
      headers: {'Accept': 'text/event-stream'},
      // SSE responses use 200 status only — bypass the ApiClient's
      // < 500 validateStatus by passing through here.
      validateStatus: (s) => s != null && s < 400,
    ),
  );

  if (response.statusCode != 200 || response.data == null) {
    throw ApiException(response.statusCode, 'Chat completion failed');
  }

  final body = response.data!;
  final lineStream = body.stream
      .map(utf8.decode)
      .transform(const LineSplitter());

  // LineSplitter already splits on \n/\r\n/\r and drops the terminator.
// So each iteration of `await for` is one complete SSE line — no need
// for an internal buffer to reassemble multi-line data blocks. (The
// old buffer/while loop was designed for a raw byte stream that
// delivered partial lines, but with LineSplitter in front it never
// got a chance to run — `indexOf('\n')` was always -1 on a
// single-line buffer, so chunks with `data:` payloads were silently
// dropped. 2026-10-04 bugfix.)
await for (final line in lineStream) {
    if (line.isEmpty) continue;
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty || payload == '[DONE]') continue;
    try {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) continue;
      final first = choices.first as Map<String, dynamic>;
      final delta = first['delta'] as Map<String, dynamic>?;
      final content = delta?['content'] as String?;
      // Reasoning chunks (delta.reasoning_content) are intentionally
      // ignored — the mobile chat UI shows only the final answer.
      // A reasoning model like milagro-chat emits both reasoning and
      // answer chunks; yielding content here yields the answer.
      if (content != null && content.isNotEmpty) yield content;
    } catch (_) {
      // Skip malformed chunks silently — SSE streams occasionally
      // contain heartbeat frames or partial JSON that we don't want
      // to surface to the chat UI as an error.
    }
  }
}
