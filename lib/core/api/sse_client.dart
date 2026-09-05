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
      .map((chunk) => utf8.decode(chunk, allowMalformed: true))
      .transform(const LineSplitter());

  String buffer = '';
  await for (final line in lineStream) {
    buffer += line;
    while (true) {
      final idx = buffer.indexOf('\n');
      if (idx < 0) break;
      final event = buffer.substring(0, idx);
      buffer = buffer.substring(idx + 1);
      if (event.isEmpty) continue;
      if (!event.startsWith('data:')) continue;
      final payload = event.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final first = choices.first as Map<String, dynamic>;
        final delta = first['delta'] as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) yield content;
      } catch (_) {
        // Skip malformed chunks.
      }
    }
  }
}
