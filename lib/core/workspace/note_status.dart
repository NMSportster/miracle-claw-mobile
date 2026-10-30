/// Task-state vocabulary shared by the Tasks list and the note detail
/// screen.
///
/// Both screens need to answer the same question — "is this thing
/// done, running, stuck, or failed?" — and they should answer it the
/// same way. Before this module the detail screen had a private
/// `_statusColor` / `_statusIcon` pair and the list screen had NO
/// status indication at all, so a user scanning their task list could
/// not tell "working on it" from "never picked up" from "failed".
///
/// The state names match what the desktop writes into the `status`
/// subkey, plus the server-side derived states:
///   * `pending`      — created by the phone, not yet picked up
///   * `in_progress`  — the desktop claimed it and is working
///   * `needs_approval` — waiting for the user to approve on the phone
///   * `done`         — finished successfully
///   * `failed`       — the desktop tried and could not complete it
///   * `skipped`      — deliberately not executed
library;

import 'package:flutter/material.dart';

/// Normalise the many spellings a producer might use into one of the
/// canonical states above.
///
/// Returns `null` for an unknown/empty state so callers can decide
/// whether to show anything at all.
String? canonicalNoteState(String? raw) {
  if (raw == null) return null;
  switch (raw.trim().toLowerCase()) {
    case 'done':
    case 'completed':
    case 'complete':
    case 'success':
    case 'succeeded':
    case 'finished':
      return 'done';
    case 'failed':
    case 'error':
    case 'failure':
      return 'failed';
    case 'in_progress':
    case 'inprogress':
    case 'running':
    case 'started':
    case 'working':
      return 'in_progress';
    case 'needs_approval':
    case 'needsapproval':
    case 'awaiting_approval':
    case 'pending_approval':
      return 'needs_approval';
    case 'skipped':
    case 'ignored':
      return 'skipped';
    case 'pending':
    case 'queued':
    case 'created':
    case 'new':
      return 'pending';
    default:
      return null;
  }
}

/// Colour for a state, using the app's theme so it works in light and
/// dark mode.
Color noteStateColor(String? state, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  switch (canonicalNoteState(state)) {
    case 'done':
      return scheme.tertiary;
    case 'failed':
      return scheme.error;
    case 'in_progress':
      return scheme.primary;
    case 'needs_approval':
      return scheme.secondary;
    case 'skipped':
      return scheme.onSurfaceVariant;
    default:
      return scheme.onSurfaceVariant;
  }
}

/// Icon for a state.
IconData noteStateIcon(String? state) {
  switch (canonicalNoteState(state)) {
    case 'done':
      return Icons.check_circle_outline;
    case 'failed':
      return Icons.error_outline;
    case 'in_progress':
      return Icons.hourglass_top;
    case 'needs_approval':
      return Icons.shield_outlined;
    case 'skipped':
      return Icons.remove_circle_outline;
    default:
      return Icons.schedule;
  }
}

/// Short human label for a state.
String noteStateLabel(String? state) {
  switch (canonicalNoteState(state)) {
    case 'done':
      return 'Done';
    case 'failed':
      return 'Failed';
    case 'in_progress':
      return 'Working';
    case 'needs_approval':
      return 'Needs approval';
    case 'skipped':
      return 'Skipped';
    case 'pending':
      return 'Queued';
    default:
      return 'Queued';
  }
}

/// A compact status pill for list rows.
///
/// Deliberately small — the list is dense, and the pill must not
/// dominate the task text. Returns an empty widget for an unknown
/// state so we never show a meaningless chip.
class NoteStateBadge extends StatelessWidget {
  const NoteStateBadge({super.key, this.state, this.compact = false});

  final String? state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canonical = canonicalNoteState(state);
    if (canonical == null) return const SizedBox.shrink();

    final color = noteStateColor(canonical, context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(noteStateIcon(canonical), size: compact ? 11 : 13, color: color),
          const SizedBox(width: 3),
          Text(
            compact ? _compactLabel(canonical) : noteStateLabel(canonical),
            style: (compact
                    ? Theme.of(context).textTheme.labelSmall
                    : Theme.of(context).textTheme.labelMedium)
                ?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Tighter wording for list rows where horizontal space is scarce.
  String _compactLabel(String canonical) {
    switch (canonical) {
      case 'in_progress':
        return 'Working';
      case 'needs_approval':
        return 'Approve';
      default:
        return noteStateLabel(canonical);
    }
  }
}
