/// Tasks / workspace list screen. Replaces the old "Connected Devices"
/// screen from the pairing era. Shows the user's notes newest-first,
/// tapping opens the detail view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/workspace/note_model.dart';
import '../../core/workspace/workspace_providers.dart';

class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesListProvider);
    final quotaAsync = ref.watch(workspaceQuotaProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notesListProvider.notifier).refresh();
      },
      child: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _emptyState(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notes.length + 1, // +1 for the quota header
            separatorBuilder: (_, i) {
              if (i == 0) return const SizedBox.shrink();
              return const Divider(height: 1);
            },
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _quotaHeader(context, quotaAsync.valueOrNull);
              }
              final n = notes[i - 1];
              return _NoteTile(note: n);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _errorState(context, ref, e),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No tasks yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Tap the + button to send your desktop a task. It\'ll show up here when it\'s done.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quotaHeader(BuildContext context, WorkspaceQuota? quota) {
    if (quota == null) return const SizedBox.shrink();
    final usedMB = (quota.usedBytes / 1024 / 1024).toStringAsFixed(1);
    final quotaMB = (quota.quotaBytes / 1024 / 1024).toStringAsFixed(0);
    final pct = quota.quotaBytes == 0
        ? 0.0
        : (quota.usedBytes / quota.quotaBytes).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 6),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$usedMB / $quotaMB MB · ${quota.tier}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Failed to load: $error'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => ref.invalidate(notesListProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final NoteSummary note;

  @override
  Widget build(BuildContext context) {
    final kind = note.requestKind ?? 'note';
    return ListTile(
      leading: _iconForKind(kind),
      title: Text(_titleFor(note)),
      subtitle: Text(
        _subtitleFor(note),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatBytes(note.totalBytes),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => context.go('/workspace/${note.noteId}'),
    );
  }

  static Widget _iconForKind(String kind) {
    IconData icon;
    switch (kind) {
      case 'reminder':
        icon = Icons.notifications_outlined;
        break;
      case 'search':
        icon = Icons.search;
        break;
      case 'file_request':
        icon = Icons.folder_outlined;
        break;
      case 'message':
        icon = Icons.send_outlined;
        break;
      default:
        icon = Icons.assignment_outlined;
    }
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: Icon(icon, size: 20),
    );
  }

  String _titleFor(NoteSummary n) {
    // No title in summary — fall back to kind or "Untitled".
    return n.requestKind != null
        ? '${n.requestKind![0].toUpperCase()}${n.requestKind!.substring(1)}'
        : 'Untitled';
  }

  String _subtitleFor(NoteSummary n) {
    final subkeys = n.subkeys.join(', ');
    final by = n.lastUpdatedBy ?? 'unknown';
    return '$subkeys · by $by';
  }

  String _formatBytes(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}K';
    return '${(b / 1024 / 1024).toStringAsFixed(1)}M';
  }
}
