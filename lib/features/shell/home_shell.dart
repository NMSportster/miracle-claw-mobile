import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';

/// HomeShell re-exports ChatScreen. Phase 2 prototype uses chat as the
/// primary post-login surface. Later phases will add a real navigation
/// rail with sessions list, modules, and settings.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) => const ChatScreen();
}
