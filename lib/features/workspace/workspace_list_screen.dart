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
            // Bottom padding accounts for the FAB cluster in home_shell.
            // Collapsed FAB = ~96px; expanded cluster adds two more
            // ~44px mini-FABs + 12px gaps + label chips. 180px keeps
            // the last list item visible above the FAB even when the
            // cluster is fully expanded. Without it the cluster overlays
            // the bottom 3 items, which David described as the icons
            // being 'scrambled among the tasks in an overlay'.
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 180),
            itemCount: all.length + 2 + (_hasMore ? 1 : 0),  // +1 for quota banner, +1 for daily summary card
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
              if (i == 1) {
                // 4D-18: daily summary card. Shows the most recent
                // daily_summary note (one per day max, per cron
                // idempotency) as a glanceable card at the top. Tapping
                // opens the detail view where the full recap lives.
                final summary = _findTodaySummary(all);
                if (summary == null) return const SizedBox.shrink();
                return _DailySummaryCard(note: summary);
              }
              final idx = i - 2;
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

/// 4D-18: find today's daily_summary note (if any).
/// The cron is idempotent — one per local day — so we just look for
/// the most recent note with request_kind='daily_summary' in the
/// first page of the list. If the user is opening the app first
/// thing in the morning, the most recent one is almost always
/// "yesterday's" (the cron runs at 03:30 UTC = 21:30 MDT).
NoteSummary? _findTodaySummary(List<NoteSummary> notes) {
  NoteSummary? best;
  for (final n in notes) {
    if (n.requestKind != 'daily_summary') continue;
    if (best == null || n.lastUpdatedAt.isAfter(best.lastUpdatedAt)) {
      best = n;
    }
  }
  return best;
}

class _DailySummaryCard extends ConsumerWidget {
  const _DailySummaryCard({required this.note});
  final NoteSummary note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The list endpoint gives summary-only entries (no subkey content).
    // We show the date label + a "tap to read" hint; the full LLM
    // recap is on the detail view (workspace_detail_screen.dart
    // _renderResult handles the `result` subkey's summary + details).
    final updatedLocal = note.lastUpdatedAt.toLocal();
    final label = _todayOrYesterday(updatedLocal);
    final scheme = Theme.of(context).colorScheme;

    // Pull the actual recap snippet so the card headline reads as
    // "Yesterday's recap — 5 things you did, 2 sessions, 0 errors"
    // instead of "Yesterday daily recap — tap to read xxxx". The
    // provider reuses noteDetailProvider's cache so the cost is just
    // one extra subkey JSON decode after the detail fetch.
    final preview = ref.watch(notePreviewProvider(note.noteId)).maybeWhen(
          data: (s) => s,
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        elevation: 0,
        color: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/workspace/${note.noteId}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.insights, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label == 'Today' || label == 'Yesterday'
                            ? "$label's recap"
                            : label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview ?? 'Tap to read the full recap',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _todayOrYesterday(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    // Older — fall back to a short date label.
    return 'Recap from ${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
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

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});
  final NoteSummary note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = note.requestKind ?? 'note';
    // Watch the per-note preview. While loading, fall back to the kind
    // label ("Voice memo", "Photo OCR") so the tile is never blank —
    // this also gives the user something meaningful during the brief
    // 200–500ms detail fetch. Once loaded, the snippet replaces it.
    final previewAsync = ref.watch(notePreviewProvider(note.noteId));
    final preview = previewAsync.maybeWhen(
      data: (s) => s,
      orElse: () => null,
    );
    final headline = preview ?? _kindLabel(kind);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: _iconForKind(kind),
      title: Text(
        headline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            if (kind != 'note')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  kind,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            if (kind != 'note') const SizedBox(width: 8),
            Expanded(
              child: Text(
                _subtitleFor(note),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
      trailing: Text(
        formatBytesShort(note.totalBytes),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      onTap: () => context.go('/workspace/${note.noteId}'),
    );
  }

  static Widget _iconForKind(String kind) {
    // Visual upgrade (2026-10-04): each kind gets a distinctive filled
    // icon + a tinted circular background. The previous design used
    // outlined monochrome icons on transparent — readable but drab.
    // Filled icons with tinted backgrounds add visual hierarchy so the
    // list scans like a real inbox: capture kinds (warm colors) read
    // as "yours", system kinds (cool colors) read as "machine".
    final (icon, bg, fg) = _kindStyle(kind);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: fg),
    );
  }

  /// Returns (icon, background, foreground) for a note kind.
  /// Colors picked from the Material 3 tonal palette: warm hues for
  /// user-captured kinds (voice / photo / search / reminder), cool
  /// hues for system kinds (context / standing instruction), and accent
  /// purple for the daily recap.
  static (IconData, Color, Color) _kindStyle(String kind) {
    switch (kind) {
      case 'reminder':
        return (
          Icons.notifications_active,
          const Color(0xFFFFE0B2), // amber 100
          const Color(0xFFE65100), // amber 900
        );
      case 'search':
        return (
          Icons.travel_explore,
          const Color(0xFFB3E5FC), // light blue 100
          const Color(0xFF01579B), // light blue 900
        );
      case 'file_request':
        return (
          Icons.folder_zip,
          const Color(0xFFFFE082), // yellow 200
          const Color(0xFF8B5A00), // dark amber
        );
      case 'message':
        return (
          Icons.send_and_archive,
          const Color(0xFFC5E1A5), // light green 200
          const Color(0xFF33691E), // light green 600
        );
      case 'context':
        return (
          Icons.dataset,
          const Color(0xFFB0BEC5), // blue grey 200
          const Color(0xFF37474F), // blue grey 800
        );
      case 'standing_instruction':
        return (
          Icons.loop,
          const Color(0xFFB39DDB), // deep purple 200
          const Color(0xFF4527A0), // deep purple 800
        );
      case 'command':
        return (
          Icons.terminal,
          const Color(0xFFCFD8DC), // blue grey 100
          const Color(0xFF263238), // blue grey 900
        );
      case 'voice_memo':
        return (
          Icons.graphic_eq,
          const Color(0xFFFFCCBC), // deep orange 100
          const Color(0xFFBF360C), // deep orange 900
        );
      case 'photo_ocr':
        return (
          Icons.document_scanner,
          const Color(0xFFB2DFDB), // teal 100
          const Color(0xFF004D40), // teal 900
        );
      case 'daily_summary':
        return (
          Icons.insights,
          const Color(0xFFE1BEE7), // purple 100
          const Color(0xFF6A1B9A), // purple 800
        );
      default:
        return (
          Icons.assignment,
          const Color(0xFFE0E0E0), // grey 300
          const Color(0xFF424242), // grey 800
        );
    }
  }

  /// Display label for a kind (used as fallback headline while the
  /// per-note preview is loading). Lowercases with spaces between
  /// underscores so "voice_memo" reads as "Voice memo" not "Voice_memo".
  static String _kindLabel(String kind) {
    if (kind == 'note') return 'Untitled';
    final spaced = kind.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _subtitleFor(NoteSummary n) {
    final by = n.lastUpdatedBy ?? 'unknown';
    final when = _relativeTime(n.lastUpdatedAt);
    return '$by · $when';
  }

  static String _relativeTime(DateTime utc) {
    final local = utc.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    // Older — fall back to a short date so it doesn't grow forever.
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
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
