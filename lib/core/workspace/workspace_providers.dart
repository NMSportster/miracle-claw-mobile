/// Riverpod providers for the MAIC per-user workspace.
///
/// The list/detail/screens consume these via ref.watch. The providers
/// own all caching + invalidation. The change-feed stream provider is
/// the source of truth for "did the desktop just write back?" — when
/// an event arrives, the list provider refreshes its cached notes.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'note_model.dart';
import 'workspace_service.dart';

// ─────────────────────────────────────────────────────────────────────
// Quota
// ─────────────────────────────────────────────────────────────────────

/// Current quota + usage for the signed-in user. Refreshed on demand
/// (after writes that might affect used_bytes) + when the change feed
/// reports a delete (since deletes decrement used_bytes).
final workspaceQuotaProvider = FutureProvider<WorkspaceQuota>((ref) async {
  final svc = ref.watch(workspaceServiceProvider);
  return svc.fetchQuota();
});

// ─────────────────────────────────────────────────────────────────────
// Notes list
// ─────────────────────────────────────────────────────────────────────

/// Cached list of note summaries, newest first. The UI watches this
/// provider; when the change feed fires, the controller invalidates
/// itself and re-fetches.
class NotesListController extends AsyncNotifier<List<NoteSummary>> {
  Timer? _refreshDebounce;

  @override
  Future<List<NoteSummary>> build() async {
    // Subscribe to the change feed. Whenever an event arrives, schedule
    // a debounced refresh (200ms — coalesces rapid bursts).
    final svc = ref.watch(workspaceServiceProvider);
    final sub = svc.events().listen((ev) {
      // Only care about events — we don't filter, any change means
      // re-fetch (the cost is small for 50 notes).
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
        ref.invalidateSelf();
      });
    });
    ref.onDispose(() {
      sub.cancel();
      _refreshDebounce?.cancel();
    });
    return svc.listNotes();
  }

  /// Force a re-fetch from the server (e.g. after the user pulls-to-refresh).
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final notesListProvider = AsyncNotifierProvider<NotesListController, List<NoteSummary>>(
  NotesListController.new,
);

// ─────────────────────────────────────────────────────────────────────
// Note detail (per-note)
// ─────────────────────────────────────────────────────────────────────

/// Cached note detail for a single note_id. The list and detail screens
/// both watch this so opening a note from the list shows the latest
/// without a round-trip (if it's already cached).
final noteDetailProvider = FutureProvider.family<NoteDetail, String>((ref, noteId) async {
  // Also subscribe to the change feed for this specific note.
  final svc = ref.watch(workspaceServiceProvider);
  final sub = svc.events().listen((ev) {
    if (ev.noteId == noteId) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);
  return svc.fetchNote(noteId);
});

// ─────────────────────────────────────────────────────────────────────
// Mutations (write/delete helpers used by UI)
// ─────────────────────────────────────────────────────────────────────

/// Result of a mutation — useful for the UI to decide whether to
/// invalidate list, show a quota error, etc.
sealed class MutationResult {
  const MutationResult();
}

class MutationOk extends MutationResult {
  const MutationOk(this.ack);
  final WriteAck ack;
}

class MutationQuotaExceeded extends MutationResult {
  const MutationQuotaExceeded(this.error);
  final WorkspaceQuotaException error;
}

class MutationError extends MutationResult {
  const MutationError(this.error);
  final Object error;
}

/// Write a subkey, then invalidate the detail + list + quota providers
/// on success so all screens reflect the new state.
Future<MutationResult> writeSubkey(
  WidgetRef ref, {
  required String noteId,
  required String subkey,
  required Map<String, dynamic> value,
}) async {
  final svc = ref.read(workspaceServiceProvider);
  try {
    final ack = await svc.writeSubkey(noteId: noteId, subkey: subkey, value: value);
    ref.invalidate(noteDetailProvider(noteId));
    ref.invalidate(notesListProvider);
    ref.invalidate(workspaceQuotaProvider);
    return MutationOk(ack);
  } on WorkspaceQuotaException catch (e) {
    return MutationQuotaExceeded(e);
  } catch (e) {
    return MutationError(e);
  }
}

/// Delete a note, then invalidate the list + quota providers.
Future<MutationResult> deleteNote(WidgetRef ref, String noteId) async {
  final svc = ref.read(workspaceServiceProvider);
  try {
    await svc.deleteNote(noteId);
    ref.invalidate(notesListProvider);
    ref.invalidate(workspaceQuotaProvider);
    ref.invalidate(noteDetailProvider(noteId));
    return MutationOk(_noopAck);
  } catch (e) {
    return MutationError(e);
  }
}

// Used by deleteNote — the ack shape doesn't matter for a delete, so
// return a sentinel. The UI just needs to know "ok, gone".
final WriteAck _noopAck = WriteAck(
  noteId: '',
  subkey: '',
  sizeBytes: 0,
  version: 0,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);
