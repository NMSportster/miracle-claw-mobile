import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Sessions — one per conversation. Mirrors MAIC's session model once
/// we wire that up (Phase 4). For now we own the full session lifecycle.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant('New chat'))();
  TextColumn get model => text().withDefault(const Constant('milagro-chat'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages — full history per session. Streams append as they arrive.
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // 'user' or 'assistant'
  TextColumn get content => text()();
  IntColumn get ordering => integer()(); // sequence within session
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Sessions, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'miracle_claw_mobile');
  }

  // --- Sessions ---

  Stream<List<Session>> watchSessions() =>
      (select(sessions)..orderBy([(s) => OrderingTerm.desc(s.updatedAt)])).watch();

  Future<List<Session>> getSessions() =>
      (select(sessions)..orderBy([(s) => OrderingTerm.desc(s.updatedAt)])).get();

  Future<Session?> getSession(String id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> upsertSession(SessionsCompanion session) =>
      into(sessions).insertOnConflictUpdate(session);

  Future<void> touchSession(String sessionId) async {
    await (update(sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteSession(String sessionId) async {
    await (delete(sessions)..where((s) => s.id.equals(sessionId))).go();
  }

  // --- Messages ---

  Stream<List<Message>> watchMessages(String sessionId) {
    return (select(messages)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([(m) => OrderingTerm.asc(m.ordering)]))
        .watch();
  }

  Future<List<Message>> getMessages(String sessionId) {
    return (select(messages)
          ..where((m) => m.sessionId.equals(sessionId))
          ..orderBy([(m) => OrderingTerm.asc(m.ordering)]))
        .get();
  }

  Future<void> upsertMessage(MessagesCompanion message) =>
      into(messages).insertOnConflictUpdate(message);

  Future<void> appendMessageContent({
    required String id,
    required String delta,
  }) async {
    await customStatement(
      'UPDATE messages SET content = content || ? WHERE id = ?',
      [delta, id],
    );
  }

  Future<void> markMessageComplete(String id) async {
    await (update(messages)..where((m) => m.id.equals(id))).write(
      const MessagesCompanion(),
    );
  }

  Future<void> deleteMessagesForSession(String sessionId) async {
    await (delete(messages)..where((m) => m.sessionId.equals(sessionId))).go();
  }
}
