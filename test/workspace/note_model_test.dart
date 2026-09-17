// note_model_test.dart — JSON round-trip + convenience helpers for the
// workspace model classes.

import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/workspace/note_model.dart';

void main() {
  group('NoteSummary', () {
    test('parses snake_case JSON from MAIC', () {
      final s = NoteSummary.fromJson({
        'note_id': '11111111-1111-4111-8111-111111111111',
        'subkeys': ['request', 'result'],
        'total_bytes': 1234,
        'last_updated_at': '2026-09-16T22:00:00Z',
        'last_updated_by': 'desktop:abc',
        'request_kind': 'reminder',
      });
      expect(s.noteId, '11111111-1111-4111-8111-111111111111');
      expect(s.subkeys, ['request', 'result']);
      expect(s.totalBytes, 1234);
      expect(s.lastUpdatedBy, 'desktop:abc');
      expect(s.requestKind, 'reminder');
      expect(s.lastUpdatedAt.isUtc, isTrue);
    });

    test('serializes back to snake_case JSON', () {
      final s = NoteSummary(
        noteId: 'n1',
        subkeys: ['request'],
        totalBytes: 0,
        lastUpdatedAt: DateTime.utc(2026, 9, 16),
        lastUpdatedBy: null,
        requestKind: null,
      );
      final json = s.toJson();
      expect(json['note_id'], 'n1');
      expect(json['last_updated_by'], isNull);
      expect(json['request_kind'], isNull);
    });
  });

  group('SubkeyContent', () {
    test('parses MAIC GET response', () {
      final sub = SubkeyContent.fromJson({
        'subkey': 'request',
        'size_bytes': 100,
        'version': 3,
        'updated_at': '2026-09-16T22:00:00Z',
        'updated_by': 'phone:abc',
        'value': {'kind': 'reminder', 'title': 'Buy milk'},
      });
      expect(sub.subkey, 'request');
      expect(sub.version, 3);
      expect(sub.value['title'], 'Buy milk');
    });
  });

  group('NoteDetail', () {
    test('parses all-subkeys response', () {
      final d = NoteDetail.fromJson({
        'note_id': 'n1',
        'subkeys': {
          'request': {
            'subkey': 'request',
            'size_bytes': 10,
            'version': 1,
            'updated_at': '2026-09-16T22:00:00Z',
            'updated_by': 'phone:abc',
            'value': {'kind': 'reminder', 'title': 'Hello'},
          },
          'result': {
            'subkey': 'result',
            'size_bytes': 20,
            'version': 2,
            'updated_at': '2026-09-16T22:05:00Z',
            'updated_by': 'desktop:xyz',
            'value': {'summary': 'Done'},
          },
        },
      });
      expect(d.noteId, 'n1');
      expect(d.subkeys.keys.toSet(), {'request', 'result'});
      expect(d.subkeys['request']!.value['title'], 'Hello');
      expect(d.subkeys['result']!.value['summary'], 'Done');
    });
  });

  group('WorkspaceQuota', () {
    test('parses quota response', () {
      final q = WorkspaceQuota.fromJson({
        'tier': 'pro',
        'quota_bytes': 1073741824,
        'used_bytes': 1024,
        'remaining_bytes': 1073740800,
        'note_ttl_days': 0,
      });
      expect(q.tier, 'pro');
      expect(q.quotaBytes, 1073741824);
      expect(q.usedBytes, 1024);
      expect(q.noteTtlDays, 0);
    });
  });

  group('validSubkeys', () {
    test('contains the 5 fixed subkey names', () {
      expect(validSubkeys, {'request', 'status', 'result', 'approval', 'history'});
    });
  });

  group('convenience helpers', () {
    final detail = NoteDetail(
      noteId: 'n1',
      subkeys: {
        'request': SubkeyContent(
          subkey: 'request',
          sizeBytes: 10,
          version: 1,
          updatedAt: DateTime.utc(2026),
          updatedBy: 'phone',
          value: {'kind': 'reminder', 'title': 'Buy milk'},
        ),
      },
    );

    test('noteTitleFromDetail returns title from request', () {
      expect(noteTitleFromDetail(detail), 'Buy milk');
    });

    test('noteKindFromDetail returns kind from request', () {
      expect(noteKindFromDetail(detail), 'reminder');
    });

    test('returns null when no request subkey', () {
      final empty = NoteDetail(noteId: 'n2', subkeys: {});
      expect(noteTitleFromDetail(empty), isNull);
      expect(noteKindFromDetail(empty), isNull);
    });
  });
}
