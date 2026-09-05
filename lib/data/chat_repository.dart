import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/sse_client.dart';
import 'db/app_database.dart';

/// Persistent chat repository. Owns sessions + messages in Drift,
/// streams via the MAIC SSE client, updates the DB as tokens arrive.
class ChatRepository {
  ChatRepository(this._db, this._api);
  final AppDatabase _db;
  final ApiClient _api;

  /// Create or load a session for the user. Returns a stream of messages.
  Future<ChatSession> startNewSession({String model = 'milagro-chat'}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    await _db.upsertSession(SessionsCompanion(
      id: drift.Value(id),
      title: const drift.Value('New chat'),
      model: drift.Value(model),
      createdAt: drift.Value(now),
      updatedAt: drift.Value(now),
    ));
    return ChatSession(id: id, title: 'New chat', model: model);
  }

  Stream<List<Message>> watchMessages(String sessionId) =>
      _db.watchMessages(sessionId);

  Stream<List<Session>> watchSessions() => _db.watchSessions();

  Future<List<Message>> getMessages(String sessionId) =>
      _db.getMessages(sessionId);

  Future<void> deleteSession(String sessionId) =>
      _db.deleteSession(sessionId);

  /// Send a user message and stream the assistant reply. The assistant
  /// message is upserted with content='' first, then updated as chunks
  /// arrive via appendMessageContent. Returns the assistant message id.
  Future<String> sendMessage({
    required String sessionId,
    required String userContent,
  }) async {
    final existing = await _db.getMessages(sessionId);
    final ordering = existing.length;

    final userMsgId = '${sessionId}_u_$ordering';
    await _db.upsertMessage(MessagesCompanion(
      id: drift.Value(userMsgId),
      sessionId: drift.Value(sessionId),
      role: const drift.Value('user'),
      content: drift.Value(userContent),
      ordering: drift.Value(ordering),
      createdAt: drift.Value(DateTime.now()),
    ));

    // First user message → title the session from it.
    if (existing.isEmpty) {
      final title = userContent.length > 40
          ? '${userContent.substring(0, 40)}…'
          : userContent;
      await _db.upsertSession(SessionsCompanion(
        id: drift.Value(sessionId),
        title: drift.Value(title),
        model: const drift.Value('milagro-chat'),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ));
    } else {
      await _db.touchSession(sessionId);
    }

    // Build history for MAIC.
    final historyMessages = [
      for (final m in existing)
        {'role': m.role, 'content': m.content},
      {'role': 'user', 'content': userContent},
    ];

    // Insert assistant placeholder.
    final asstMsgId = '${sessionId}_a_$ordering';
    await _db.upsertMessage(MessagesCompanion(
      id: drift.Value(asstMsgId),
      sessionId: drift.Value(sessionId),
      role: const drift.Value('assistant'),
      content: const drift.Value(''),
      ordering: drift.Value(ordering + 1),
      createdAt: drift.Value(DateTime.now()),
    ));

    try {
      await for (final chunk in streamChatCompletion(
        dio: _api.dio,
        model: 'milagro-chat',
        messages: historyMessages.cast<Map<String, String>>(),
      )) {
        await _db.appendMessageContent(id: asstMsgId, delta: chunk);
      }
    } catch (e) {
      await _db.appendMessageContent(
        id: asstMsgId,
        delta: '\n\n[Error: $e]',
      );
      rethrow;
    }

    return asstMsgId;
  }
}

/// Lightweight value type for the UI layer.
class ChatSession {
  ChatSession({required this.id, required this.title, required this.model});
  final String id;
  final String title;
  final String model;
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(apiClientProvider);
  return ChatRepository(db, api);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
