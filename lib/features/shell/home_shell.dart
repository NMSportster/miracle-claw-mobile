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

    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_selectedIndex].label),
        actions: [
          if (_selectedIndex == 1) ...[
            IconButton(
              icon: const Icon(Icons.mic_none_outlined),
              tooltip: 'Voice memo',
              onPressed: () => context.push('/capture/voice'),
            ),
            IconButton(
              icon: const Icon(Icons.photo_camera_outlined),
              tooltip: 'Photo OCR',
              onPressed: () => context.push('/capture/photo'),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New task',
              onPressed: () => context.push('/workspace/new'),
            ),
          ],
        ],
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
