/// Tests for the shared task-state vocabulary.
///
/// The Tasks list and the note detail screen must agree on what a task's
/// state is and how it looks. Before `note_status.dart` existed, the
/// detail screen had a private colour/icon switch and the list screen
/// had NO status indication at all — so a user could not tell "queued"
/// from "working on it" from "failed" without opening every note.
///
/// These tests pin the canonicalisation rules and the server-derived
/// fallback, so the two screens can't drift apart again.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miracle_claw_mobile/core/workspace/note_status.dart';

void main() {
  group('canonicalNoteState', () {
    test('maps the desktop-written states', () {
      expect(canonicalNoteState('done'), 'done');
      expect(canonicalNoteState('in_progress'), 'in_progress');
      expect(canonicalNoteState('needs_approval'), 'needs_approval');
      expect(canonicalNoteState('failed'), 'failed');
      expect(canonicalNoteState('skipped'), 'skipped');
      expect(canonicalNoteState('pending'), 'pending');
    });

    test('maps common synonyms to the same canonical state', () {
      expect(canonicalNoteState('completed'), 'done');
      expect(canonicalNoteState('success'), 'done');
      expect(canonicalNoteState('finished'), 'done');
      expect(canonicalNoteState('running'), 'in_progress');
      expect(canonicalNoteState('started'), 'in_progress');
      expect(canonicalNoteState('error'), 'failed');
      expect(canonicalNoteState('queued'), 'pending');
      expect(canonicalNoteState('awaiting_approval'), 'needs_approval');
    });

    test('is case and whitespace insensitive', () {
      expect(canonicalNoteState('DONE'), 'done');
      expect(canonicalNoteState('  in_progress  '), 'in_progress');
      expect(canonicalNoteState('Failed'), 'failed');
    });

    test('returns null for unknown or absent states', () {
      expect(canonicalNoteState(null), isNull);
      expect(canonicalNoteState(''), isNull);
      expect(canonicalNoteState('wat'), isNull);
    });
  });

  group('noteStateLabel', () {
    test('uses plain language a customer can act on', () {
      expect(noteStateLabel('in_progress'), 'Working');
      expect(noteStateLabel('needs_approval'), 'Needs approval');
      expect(noteStateLabel('done'), 'Done');
      expect(noteStateLabel('failed'), 'Failed');
      expect(noteStateLabel('pending'), 'Queued');
    });
  });

  group('noteStateIcon', () {
    test('gives distinct icons for distinct states', () {
      final done = noteStateIcon('done');
      final failed = noteStateIcon('failed');
      final working = noteStateIcon('in_progress');
      final pending = noteStateIcon('pending');
      expect(done, isNot(failed));
      expect(failed, isNot(working));
      expect(working, isNot(pending));
    });
  });

  group('NoteStateBadge', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('renders the state label for a known state', (tester) async {
      await tester.pumpWidget(wrap(const NoteStateBadge(state: 'in_progress')));
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('renders nothing for an unknown state', (tester) async {
      await tester.pumpWidget(wrap(const NoteStateBadge(state: 'nonsense')));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing when the state is null', (tester) async {
      await tester.pumpWidget(wrap(const NoteStateBadge(state: null)));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the compact label in compact mode', (tester) async {
      await tester.pumpWidget(
        wrap(const NoteStateBadge(state: 'needs_approval', compact: true)),
      );
      expect(find.text('Approve'), findsOneWidget);
    });
  });
}
