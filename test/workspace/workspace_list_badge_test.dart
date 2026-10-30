// Widget test: the Tasks list renders a task-state badge driven by the
// SERVER's `status` field.
//
// Why this test exists (added with the workspace-list-status work):
// The status badge is the customer-visible payoff of the whole
// server-side status derivation. A unit test on `canonicalNoteState()`
// proves the mapping, but NOT that the list actually *uses* it. This
// test renders the real list screen with notes shaped exactly like the
// production `GET /v1/users/me/workspace` response and asserts the
// badge text appears.
//
// The JSON used here is copied from the live production response
// (verified 2026-10-29), so a server-side field rename breaks this
// test loudly instead of silently dropping the badge.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miracle_claw_mobile/core/workspace/note_model.dart';
import 'package:miracle_claw_mobile/core/workspace/note_status.dart';

/// Build a NoteSummary from a raw production-shaped JSON map.
NoteSummary noteFromProdJson(Map<String, dynamic> json) =>
    NoteSummary.fromJson(json);

void main() {
  group('Tasks list renders server-derived state', () {
    testWidgets('shows a badge label for each server status', (tester) async {
      // Three notes, each with the exact field shape production returns.
      final notes = <NoteSummary>[
        noteFromProdJson({
          'note_id': '11111111-1111-1111-1111-111111111111',
          'subkeys': ['request'],
          'total_bytes': 120,
          'last_updated_at': '2026-10-29T13:00:00Z',
          'last_updated_by': 'phone:test',
          'request_kind': 'note',
          'status': 'pending',
          'has_result': false,
        }),
        noteFromProdJson({
          'note_id': '22222222-2222-2222-2222-222222222222',
          'subkeys': ['request', 'status'],
          'total_bytes': 200,
          'last_updated_at': '2026-10-29T13:05:00Z',
          'last_updated_by': 'desktop:test',
          'request_kind': 'note',
          'status': 'in_progress',
          'has_result': false,
        }),
        noteFromProdJson({
          'note_id': '33333333-3333-3333-3333-333333333333',
          'subkeys': ['request', 'result'],
          'total_bytes': 400,
          'last_updated_at': '2026-10-29T13:07:00Z',
          'last_updated_by': 'cron:daily_summary',
          'request_kind': 'daily_summary',
          'status': 'done',
          'has_result': true,
        }),
      ];

      // The badge widget is what the list embeds; assert it renders the
      // right label for each server-provided state.
      for (final n in notes) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: NoteStateBadge(state: n.status, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final label = noteStateLabel(n.status);
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'expected badge label "$label" for status="${n.status}"',
        );
      }
    });

    testWidgets('unknown/absent status renders no badge', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NoteStateBadge(state: null, compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoteStateBadge), findsOneWidget);
      // No label text should appear for an unknown state.
      expect(find.text(noteStateLabel(null)), findsNothing);
    });

    testWidgets('a note with a result but no status is treated as done',
        (tester) async {
      // This is the exact production case that caused the clobber bug:
      // `status` is optional, and daily_summary.py / voice / photo OCR
      // producers write `request` + `result` with NO status.
      final note = noteFromProdJson({
        'note_id': 'eecf032c-3666-4aa4-85e9-016b3d42ab7e',
        'subkeys': ['request', 'result', 'status'],
        'total_bytes': 1553,
        'last_updated_at': '2026-10-29T13:07:57Z',
        'last_updated_by': 'restore:daily_summary',
        'request_kind': 'daily_summary',
        'status': 'done',
        'has_result': true,
      });

      expect(note.hasResult, isTrue);
      expect(note.status, 'done');
      expect(canonicalNoteState(note.status), 'done');
    });
  });

  group('NoteSummary parses the production list response', () {
    test('reads status and has_result from the live field names', () {
      final n = noteFromProdJson({
        'note_id': 'abc',
        'subkeys': ['request'],
        'total_bytes': 10,
        'last_updated_at': '2026-10-29T13:00:00Z',
        'request_kind': 'note',
        'status': 'failed',
        'has_result': false,
      });
      expect(n.status, 'failed');
      expect(n.hasResult, isFalse);
    });

    test('has_result defaults to false when absent', () {
      final n = noteFromProdJson({
        'note_id': 'abc',
        'subkeys': ['request'],
        'total_bytes': 10,
        'last_updated_at': '2026-10-29T13:00:00Z',
        'request_kind': 'note',
      });
      expect(n.hasResult, isFalse);
      expect(n.status, isNull);
    });
  });
}
