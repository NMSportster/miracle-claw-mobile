/// Tasks / workspace list screen. Replaces the old "Connected Devices"
/// screen from the pairing era. Shows the user's notes newest-first,
/// tapping opens the detail view.
///
/// 4B updates:
///   - 6: friendly empty state with onboarding copy + quick capture CTA
///   - 7: shared 5-state widgets (LoadingState / EmptyStateView / ErrorRetry / PartialBanner)
///   - 9: load-more pagination via existing limit/offset backend params
///   - carry: quota label fixed (was showing bytes as MB due to a divide-by-1024 that's only right for kibibytes; switched to a real base-1024 KB/MB/GB formatter)
///   - 10: pull-to-refresh works (kept; same RefreshIndicator)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/workspace/note_model.dart';
import '../../core/workspace/workspace_providers.dart';
import '../../core/workspace/workspace_service.dart';
import 'workspace_states.dart';

class WorkspaceListScreen extends ConsumerStatefulWidget {
  const WorkspaceListScreen({super.key});

  @override
  ConsumerState<WorkspaceListScreen> createState() => _WorkspaceListScreenState();
}

class _WorkspaceListScreenState extends ConsumerState<WorkspaceListScreen> {
  // 4B-9: pagination state. Server default is limit=50; ask for more on scroll.
  static const _pageSize = 50;
  final List<NoteSummary> _extra = []; // older pages appended
  bool _hasMore = true;
  bool _loadingMore = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final svc = ref.read(workspaceServiceProvider);
      // Default offset for the first page is 0; subsequent pages query
      // the same list endpoint with offset = _extra.length + pageSize.
      final older = await svc.listNotes(
        limit: _pageSize,
        offset: _extra.length + _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _extra.addAll(older);
        if (older.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      // Surface the failure as a short snackbar (using the friendly
      // userMessage from WorkspaceException). Don't block the list —
      // what we have so far is still usable.
      if (mounted) {
        final msg = e is WorkspaceException
            ? e.userMessage
            : 'Couldn\'t load more: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final quotaAsync = ref.watch(workspaceQuotaProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notesListProvider.notifier).refresh();
        if (!mounted) return;
        setState(() {
          _extra.clear();
          _hasMore = true;
        });
      },
      child: notesAsync.when(
        data: (firstPage) {
          final all = [...firstPage, ..._extra];
          if (all.isEmpty) {
            return EmptyStateView(
              icon: Icons.assignment_outlined,
              title: 'Welcome to Tasks',
              message:
                  'Capture a thought, ask your desktop to do something, '
                  'or see results from your last session. Tap + to start.',
              actionLabel: 'New task',
              onAction: () => context.go('/workspace/new'),
            );
          }
          return ListView.separated(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: all.length + 1 + (_hasMore ? 1 : 0),
            separatorBuilder: (_, i) {
              if (i == 0) return const SizedBox.shrink();
              return const Divider(height: 1);
            },
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return _QuotaBanner(
                  quota: quotaAsync,
                  // 4B-7: surface partial-quota-failure as a banner, not a crash.
                  onQuotaRetry: () => ref.invalidate(workspaceQuotaProvider),
                );
              }
              final idx = i - 1;
              if (idx < all.length) {
                return _NoteTile(note: all[idx]);
              }
              // footer (load more)
              return _LoadMoreFooter(
                loading: _loadingMore,
                hasMore: _hasMore,
                onTap: _loadMore,
              );
            },
          );
        },
        loading: () => const LoadingState(),
        error: (e, _) => ErrorRetry(
          message: e is WorkspaceException ? e.userMessage : 'Failed to load: $e',
          onRetry: () => ref.invalidate(notesListProvider),
        ),
      ),
    );
  }
}

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({required this.quota, required this.onQuotaRetry});
  final AsyncValue<WorkspaceQuota> quota;
  final VoidCallback onQuotaRetry;

  @override
  Widget build(BuildContext context) {
    return quota.when(
      data: (q) {
        final pct = q.quotaBytes == 0
            ? 0.0
            : (q.usedBytes / q.quotaBytes).clamp(0.0, 1.0);
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
                '${_formatBytes(q.usedBytes)} / ${_formatBytes(q.quotaBytes)} · ${q.tier}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 8),
      error: (e, _) => PartialBanner(
        message: 'Quota unavailable: $e',
        onRetry: onQuotaRetry,
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.hasMore, required this.onTap});
  final bool loading;
  final bool hasMore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'End of list',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onTap,
                child: const Text('Load more'),
              ),
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
        formatBytesShort(note.totalBytes),
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
      case 'context':
        icon = Icons.layers_outlined;
        break;
      case 'standing_instruction':
        icon = Icons.repeat_on_outlined;
        break;
      case 'command':
        icon = Icons.bolt_outlined;
        break;
      case 'voice_memo':
        icon = Icons.mic_none_outlined;
        break;
      case 'photo_ocr':
        icon = Icons.image_outlined;
        break;
      case 'daily_summary':
        icon = Icons.today_outlined;
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
    if (n.requestKind != null) {
      return '${n.requestKind![0].toUpperCase()}${n.requestKind!.substring(1)}';
    }
    return 'Untitled';
  }

  String _subtitleFor(NoteSummary n) {
    final subkeys = n.subkeys.isEmpty ? '—' : n.subkeys.join(', ');
    final by = n.lastUpdatedBy ?? 'unknown';
    return '$subkeys · by $by';
  }
}

/// Human-friendly byte formatter: shows bytes / KB / MB / GB.
/// 4B carry-fix: the previous `'/ 1024 / 1024'` math assumed MaIC was
/// storing in kibibytes; it actually returns plain bytes, so the
/// label printed like "0.0 / 10240 MB · pro" which read as 10GB but
/// was actually pretending to display raw bytes as if they were MB.
String _formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Compact form: 347B / 12K / 1.4M / 2.3G. Reused in tile trailing slot.
String formatBytesShort(int b) {
  if (b < 1024) return '${b}B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}K';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)}M';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)}G';
}
