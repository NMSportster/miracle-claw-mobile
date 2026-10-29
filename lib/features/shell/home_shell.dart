import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../chat/chat_screen.dart';
import '../workspace/workspace_list_screen.dart';
import '../../core/workspace/workspace_providers.dart';

/// Top-level shell after sign-in. Two destinations:
///   - Chat (default — the primary use case)
///   - Tasks (the per-user workspace — phone ↔ desktop message bus)
///
/// 2026-09-16 pivot: replaces the old "Connected Devices" pairing
/// destination. See memory/projects/workspace_architecture.md.
///
/// Uses `Drawer` rather than `NavigationRail` so it works on phones in
/// portrait without taking permanent screen space. Material 3 design
/// guidance: NavigationDrawer is the mobile-friendly pattern when there
/// are 2–5 top-level destinations.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  /// Whether the Tasks FAB cluster (SpeedDial) is expanded. Owned here
  /// rather than inside the cluster widget so the scrim can be a
  /// sibling of the FAB in the widget tree (it has to render *on top*
  /// of the FAB, not under it) and the two stay in sync.
  final ValueNotifier<bool> _fabExpanded = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _fabExpanded.dispose();
    super.dispose();
  }

  void _toggleFab() {
    _fabExpanded.value = !_fabExpanded.value;
  }

  void _collapseFab() {
    if (_fabExpanded.value) _fabExpanded.value = false;
  }

  static const _destinations = <_NavDestination>[
    _NavDestination(
      label: 'Chat',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
    ),
    _NavDestination(
      label: 'Tasks',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
    ),
  ];

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const ChatScreen();
      case 1:
        return const WorkspaceListScreen();
      default:
        return const ChatScreen();
    }
  }

  void _onSelect(int i) {
    setState(() => _selectedIndex = i);
    Navigator.of(context).pop(); // close the drawer
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    // Badge the Tasks entry when there's data and the user isn't on
    // the Tasks tab right now. Simple proxy for "new since last visit".
    final showTasksBadge = _selectedIndex != 1 &&
        notesAsync.maybeWhen(
          data: (n) => n.isNotEmpty,
          orElse: () => false,
        );

    // Tasks screen exposes three capture actions via a FAB cluster
    // (Material 3 SpeedDial). At rest: one + button. On tap: expands
    // to show New task, Voice memo, Photo OCR with visible labels so
    // the user doesn't have to long-press to discover what each does.
    // See home_shell speed-dial state in _FabExpanded below.
    final showFab = _selectedIndex == 1;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(_destinations[_selectedIndex].label),
          ),
          drawer: NavigationDrawer(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onSelect,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 10),
                child: Text(
                  'Miracle Claw',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (var i = 0; i < _destinations.length; i++)
                NavigationDrawerDestination(
                  icon: i == 1 && showTasksBadge
                      ? Badge(
                          smallSize: 8,
                          child: Icon(_destinations[i].icon),
                        )
                      : Icon(_destinations[i].icon),
                  selectedIcon: i == 1 && showTasksBadge
                      ? Badge(
                          smallSize: 8,
                          child: Icon(_destinations[i].selectedIcon),
                        )
                      : Icon(_destinations[i].selectedIcon),
                  label: Text(_destinations[i].label),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 16),
                child: Text(
                  'v1.0.0+1',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          body: _pageFor(_selectedIndex),
          floatingActionButton: showFab
              ? _TasksFabCluster(
                  expanded: _fabExpanded,
                  onToggle: _toggleFab,
                  onCollapse: _collapseFab,
                )
              : null,
        ),
        // Scrim over the whole Scaffold, shown only while the FAB
        // cluster is expanded. It dims the list AND the FAB cluster so
        // the expanded state reads as a deliberate overlay instead of
        // "scrambled icons stacked on top of text". Tapping it
        // collapses the cluster.
        //
        // This lives OUTSIDE the Scaffold on purpose: Scaffold lays
        // `floatingActionButton` above `body`, so a scrim placed
        // inside `body` renders *underneath* the FAB cluster (FABs stay
        // bright on a dimmed list) and swallows taps meant for the
        // FABs. Putting it last in an outer Stack puts it on top.
        if (showFab)
          ValueListenableBuilder<bool>(
            valueListenable: _fabExpanded,
            builder: (context, expanded, _) {
              return IgnorePointer(
                ignoring: !expanded,
                child: AnimatedOpacity(
                  opacity: expanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _collapseFab,
                    child: Container(color: Colors.black.withValues(alpha: 0.4)),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// FAB cluster for the Tasks screen. Speed-dial pattern: one main
/// `+` FAB at rest; tapping it expands two satellite mini-FABs
/// (Voice memo, Photo OCR) above it, each with a visible label so
/// the user doesn't have to long-press to discover what they do.
///
/// Why a cluster instead of three AppBar icons:
///   - The previous design had three mystery icons in the AppBar
///     (mic / camera / +) with only tooltip-level discoverability.
///     David flagged this as opaque — users had no idea what each
///     button did until they tapped-and-held.
///   - Material 3 spec puts the primary action on FAB. Voice + photo
///     are quick-capture siblings, so they live as speed-dial children.
///   - Tapping outside the cluster collapses it (FocusScope).
///
/// The expansion state is owned by [_HomeShellState] and passed in, so
/// the scrim — a sibling of this widget in the outer Stack — can render
/// on top of it and stay in sync.
class _TasksFabCluster extends StatelessWidget {
  const _TasksFabCluster({
    required this.expanded,
    required this.onToggle,
    required this.onCollapse,
  });

  final ValueNotifier<bool> expanded;
  final VoidCallback onToggle;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FocusScope(
      // Tapping outside the cluster should close it.
      onFocusChange: (has) {
        if (!has) onCollapse();
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: expanded,
        builder: (context, isExpanded, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isExpanded) ...[
                _MiniFab(
                  icon: Icons.graphic_eq,
                  label: 'Voice memo',
                  accent: const Color(0xFFBF360C), // deep orange 900
                  onTap: () {
                    onCollapse();
                    context.push('/capture/voice');
                  },
                ),
                const SizedBox(height: 12),
                _MiniFab(
                  icon: Icons.document_scanner,
                  label: 'Photo OCR',
                  accent: const Color(0xFF004D40), // teal 900
                  onTap: () {
                    onCollapse();
                    context.push('/capture/photo');
                  },
                ),
                const SizedBox(height: 12),
              ],
              // Main FAB: large (extended) with primary gradient. The
              // gradient is the visual cue that this is the primary action —
              // mini-FABs above use a flat secondaryContainer so they read
              // as siblings, not co-equals.
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.large(
                  onPressed: onToggle,
                  backgroundColor: Colors.transparent,
                  foregroundColor: scheme.onPrimary,
                  elevation: 0,
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        key: ValueKey(isExpanded),
                        isExpanded ? Icons.close : Icons.add,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Single mini-FAB in the speed-dial: icon button + a small label
/// chip to its left so the user can read what it does without
/// long-pressing to see a tooltip.
class _MiniFab extends StatelessWidget {
  const _MiniFab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = accent ?? scheme.onSecondaryContainer;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visible label chip — fixes the "mystery icon" complaint.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: 'mini_$label',
          onPressed: onTap,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: color,
          elevation: 2,
          child: Icon(icon),
        ),
      ],
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
