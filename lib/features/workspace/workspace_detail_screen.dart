/// Workspace note detail screen. Shows all subkeys of one note and
/// (when present) the desktop's result. Pulls the latest version on
/// each entry, so as the desktop writes back the user sees updates.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/workspace/note_model.dart';
import '../../core/workspace/workspace_providers.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Failed to load: $e'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(noteDetailProvider(noteId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
    final result = await deleteNote(ref, noteId);
    if (!context.mounted) return;
    switch (result) {
      case MutationOk():
        context.pop();
      case MutationError(:final error):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
      case MutationQuotaExceeded():
        // Deletion always frees quota, so this shouldn't fire — but if it does,
        // the server is telling us something is wrong.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quota error: ${result.error}')));
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
    children.add(_Header(title: title, kind: kind, subkeys: detail.subkeys.keys.toList()));

    // Subkey cards in fixed order
    const order = ['request', 'status', 'result', 'approval', 'history'];
    for (final sk in order) {
      final sub = detail.subkeys[sk];
      if (sub == null) continue;
      children.add(_SubkeyCard(subkey: sub));
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

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.kind, required this.subkeys});
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
          Row(
            children: [
              _chip(context, kind),
              const SizedBox(width: 8),
              for (final sk in subkeys) ...[
                _chip(context, sk, secondary: true),
                const SizedBox(width: 6),
              ],
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

class _SubkeyCard extends StatelessWidget {
  const _SubkeyCard({required this.subkey});
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
                    'v${subkey.version} · $updatedAt',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('by $by', style: Theme.of(context).textTheme.bodySmall),
              const Divider(),
              _renderValue(context, subkey.value),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderValue(BuildContext context, Map<String, dynamic> value) {
    if (subkey.subkey == 'result') {
      return _renderResult(context, value);
    }
    if (subkey.subkey == 'request') {
      return _renderRequest(context, value);
    }
    // Generic: pretty-print the JSON
    return SelectableText(
      const JsonEncoder.withIndent('  ').convert(value),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }

  Widget _renderRequest(BuildContext context, Map<String, dynamic> v) {
    final title = v['title'] as String?;
    final text = v['text'] as String?;
    final needsApproval = (v['needs_approval_for'] as List?)?.cast<String>() ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
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

  Widget _renderResult(BuildContext context, Map<String, dynamic> v) {
    final summary = v['summary'] as String?;
    final details = v['details'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          ),
        if (details != null) Text(details),
      ],
    );
  }
}
