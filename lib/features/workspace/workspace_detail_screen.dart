/// Workspace note detail screen. Shows all subkeys of one note and
/// (when present) the desktop's result. Pulls the latest version on
/// each entry, so as the desktop writes back the user sees updates.
///
/// 4B-8: per-subkey renderers (request / status / result / approval /
/// history cards). Each subkey now has a custom layout instead of a
/// generic JSON dump.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/workspace/note_model.dart';
import '../../core/workspace/workspace_providers.dart';
import '../../core/workspace/workspace_service.dart' show WorkspaceException;
import 'workspace_states.dart';

class WorkspaceDetailScreen extends ConsumerWidget {
  const WorkspaceDetailScreen({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(noteDetailProvider(noteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: [
          detailAsync.maybeWhen(
            data: (_) => IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, ref),
            ),
            orElse: () => null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: detailAsync.when(
        data: (detail) => _NoteDetailBody(detail: detail),
        loading: () => const LoadingState(),
        error: (e, _) => ErrorRetry(
          message: e is WorkspaceException ? e.userMessage : 'Failed to load: $e',
          onRetry: () => ref.invalidate(noteDetailProvider(noteId)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // Capture context-dependent objects BEFORE any await so we don't
    // touch `context` past the dialog boundary (Flutter analyzer flags
    // this as `use_build_context_synchronously`).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text(
          'This removes the task from your workspace and frees the storage. '
          'Your desktop may still have it cached locally.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 4B-11: optimistic delete with 5s undo window.
    //
    // We fire the actual DELETE so the list provider re-fetches without
    // the row, and offer the user a single-shot undo: if they tap it,
    // we re-create the note by re-PUTting the request subkey. The
    // desktop already had a cached copy so it picks up the restored row
    // on its next poll.
    final requestValue = _safeSnapshotRequestValue(ref);
    final backupApproval = _safeSnapshotApprovalValue(ref);

    final result = await deleteNote(ref, noteId);

    void restore() async {
      if (requestValue == null && backupApproval == null) return;  // nothing to restore
      if (requestValue != null) {
        final r = await writeSubkey(ref, noteId: noteId, subkey: 'request', value: requestValue);
        if (r is! MutationOk) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not restore task.')),
          );
          return;
        }
      }
      if (backupApproval != null) {
        await writeSubkey(ref, noteId: noteId, subkey: 'approval', value: backupApproval);
      }
    }

    switch (result) {
      case MutationOk():
        // Pop safely; if the navigator is gone we just stay where we are.
        if (navigator.canPop()) navigator.pop();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Task deleted'),
            duration: const Duration(seconds: 5),
            action: (requestValue == null && backupApproval == null)
                ? null
                : SnackBarAction(
                    label: 'Undo',
                    onPressed: restore,
                  ),
          ),
        );
      case MutationError(:final error):
        messenger.showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      case MutationQuotaExceeded():
        messenger.showSnackBar(SnackBar(content: Text('Quota error: ${result.error}')));
    }
  }

  /// Best-effort snapshot of the request subkey's value so we can put it
  /// back if the user taps Undo within 5s.
  Map<String, dynamic>? _safeSnapshotRequestValue(WidgetRef ref) {
    try {
      final async = ref.read(noteDetailProvider(noteId));
      return async.maybeWhen(
        data: (d) => d.subkeys['request']?.value,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _safeSnapshotApprovalValue(WidgetRef ref) {
    try {
      final async = ref.read(noteDetailProvider(noteId));
      return async.maybeWhen(
        data: (d) => d.subkeys['approval']?.value,
        orElse: () => null,
      );
    } catch (_) {
      return null;
    }
  }
}

class _NoteDetailBody extends StatelessWidget {
  const _NoteDetailBody({required this.detail});
  final NoteDetail detail;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    // Header: title from request subkey
    final title = noteTitleFromDetail(detail) ?? 'Untitled';
    final kind = noteKindFromDetail(detail) ?? 'note';
    children.add(_DetailHeader(title: title, kind: kind, subkeys: detail.subkeys.keys.toList()));

    // Subkey cards in fixed order
    const order = ['request', 'status', 'result', 'approval', 'history'];
    for (final sk in order) {
      final sub = detail.subkeys[sk];
      if (sub == null) continue;
      children.add(SubkeyCard(subkey: sub));
    }

    if (children.length == 1) {
      children.add(const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('This note has no content.')),
      ));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: children,
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.kind, required this.subkeys});
  final String title;
  final String kind;
  final List<String> subkeys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(context, kind),
              for (final sk in subkeys) _chip(context, sk, secondary: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, String label, {bool secondary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: secondary
            ? Theme.of(ctx).colorScheme.surfaceContainerHigh
            : Theme.of(ctx).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
              color: secondary
                  ? Theme.of(ctx).colorScheme.onSurfaceVariant
                  : Theme.of(ctx).colorScheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

/// Card for one subkey. Dispatches to a type-specific renderer based on
/// the subkey name; unknown subkeys fall back to pretty-printed JSON.
///
/// 4B-8 per-subkey layout:
///   request  — what the user/phone asked for (kind, title, text, needs_approval_for)
///   status   — desktop progress timeline (state, message, percent)
///   result   — desktop output (summary, details, attachments)
///   approval — explicit approve/deny or pending state
///   history  — append-only log; render as timeline
class SubkeyCard extends StatelessWidget {
  const SubkeyCard({super.key, required this.subkey});
  final SubkeyContent subkey;

  @override
  Widget build(BuildContext context) {
    final updatedAt = DateFormat.yMMMd().add_jm().format(subkey.updatedAt.toLocal());
    final by = subkey.updatedBy ?? 'unknown';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    subkey.subkey.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    'by $by',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'v${subkey.version} · $updatedAt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _renderValue(context, subkey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderValue(BuildContext context, SubkeyContent subkey) {
    switch (subkey.subkey) {
      case 'request':
        return _renderRequest(context, subkey.value);
      case 'status':
        return _renderStatus(context, subkey.value);
      case 'result':
        return _renderResult(context, subkey.value);
      case 'approval':
        return _renderApproval(context, subkey.value);
      case 'history':
        return _renderHistory(context, subkey.value);
      default:
        return _renderGeneric(context, subkey.value);
    }
  }

  Widget _renderRequest(BuildContext context, Map<String, dynamic> v) {
    final title = v['title'] as String?;
    final text = v['text'] as String?;
    final kind = v['kind'] as String?;
    final needsApproval = ((v['needs_approval_for'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kind != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Kind: $kind', style: Theme.of(context).textTheme.bodySmall),
          ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        if (text != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text),
          ),
        if (needsApproval.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Requires approval: ${needsApproval.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _renderStatus(BuildContext context, Map<String, dynamic> v) {
    final state = (v['state'] ?? v['status'] ?? 'unknown').toString();
    final message = v['message']?.toString();
    final percent = (v['percent'] is num) ? (v['percent'] as num).toInt() : null;
    final color = _statusColor(state, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_statusIcon(state), color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              state,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(message),
          ),
        if (percent != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0), minHeight: 6),
          ),
          const SizedBox(height: 4),
          Text('$percent%', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _renderResult(BuildContext context, Map<String, dynamic> v) {
    final summary = v['summary']?.toString();
    final details = v['details']?.toString();
    final attachmentList = ((v['attachments'] as List?) ?? const [])
        .cast<Map>()
        .map((m) => m['name']?.toString())
        .whereType<String>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          ),
        if (details != null) Text(details),
        if (attachmentList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final a in attachmentList)
                  Chip(
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: Text(a),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _renderApproval(BuildContext context, Map<String, dynamic> v) {
    final approved = v['approved'] == true;
    final denied = v['approved'] == false;
    final approver = v['approver']?.toString();
    final reason = v['reason']?.toString();

    final color = approved
        ? Theme.of(context).colorScheme.tertiary
        : denied
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.secondary;
    final icon = approved
        ? Icons.check_circle
        : denied
            ? Icons.cancel
            : Icons.hourglass_top;
    final label = approved ? 'Approved' : denied ? 'Denied' : 'Pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
          ],
        ),
        if (approver != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('by $approver', style: Theme.of(context).textTheme.bodySmall),
          ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(reason),
          ),
      ],
    );
  }

  Widget _renderHistory(BuildContext context, Map<String, dynamic> v) {
    // history can be a raw list OR a {entries: [...]} envelope
    dynamic raw = v['entries'] ?? v;
    if (raw is! List) raw = const <dynamic>[];
    final entries = raw;

    if (entries.isEmpty) {
      return Text('No history yet.', style: Theme.of(context).textTheme.bodySmall);
    }
    final fmt = DateFormat.yMMMd().add_jm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          Builder(builder: (_) {
            final item = entries[i];
            String label = 'event';
            DateTime? at;
            if (item is Map) {
              final evt = item['event']?.toString();
              final msg = item['message']?.toString();
              label = (evt != null && evt.isNotEmpty)
                  ? evt
                  : (msg != null && msg.isNotEmpty ? msg : 'event');
              final atRaw = item['at'];
              if (atRaw != null) {
                try { at = DateTime.parse(atRaw.toString()).toLocal(); } catch (_) {}
              }
            } else {
              label = item.toString();
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.bodyMedium),
                      if (at != null)
                        Text(fmt.format(at), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            );
          }),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _renderGeneric(BuildContext context, Map<String, dynamic> v) {
    return SelectableText(
      const JsonEncoder.withIndent('  ').convert(v),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }

  Color _statusColor(String state, BuildContext context) {
    switch (state) {
      case 'done':
      case 'completed':
      case 'success':
      case 'finished':
        return Theme.of(context).colorScheme.tertiary;
      case 'error':
      case 'failed':
        return Theme.of(context).colorScheme.error;
      case 'running':
      case 'in_progress':
      case 'started':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _statusIcon(String state) {
    switch (state) {
      case 'done':
      case 'completed':
      case 'success':
      case 'finished':
        return Icons.check_circle_outline;
      case 'error':
      case 'failed':
        return Icons.error_outline;
      case 'running':
      case 'in_progress':
      case 'started':
        return Icons.hourglass_top;
      case 'queued':
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.info_outline;
    }
  }
}
