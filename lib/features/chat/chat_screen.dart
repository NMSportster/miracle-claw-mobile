import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/sse_client.dart';
import '../../core/auth/auth_repository.dart';

/// In-memory session store for Phase 2 prototype. Will move to Drift in
/// the polish pass.
class ChatMessage {
  ChatMessage({required this.role, required this.content, this.streaming = false});
  final String role; // 'user' or 'assistant'
  String content;
  bool streaming;
}

class ChatSession {
  ChatSession({required this.id, required this.title, required this.messages});
  final String id;
  final String title;
  final List<ChatMessage> messages;
}

/// Riverpod-managed chat state. Phase 2 prototype: list of sessions with
/// message histories, all in memory.
class ChatNotifier extends StateNotifier<List<ChatSession>> {
  ChatNotifier(this._ref) : super(const []);

  final Ref _ref;
  bool _busy = false;

  bool get isBusy => _busy;

  /// Start a new session with the given first user message.
  Future<void> startNewSession(String userMessage) async {
    if (_busy) return;
    _busy = true;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = ChatSession(
      id: id,
      title: userMessage.length > 40 ? '${userMessage.substring(0, 40)}…' : userMessage,
      messages: [
        ChatMessage(role: 'user', content: userMessage),
        ChatMessage(role: 'assistant', content: '', streaming: true),
      ],
    );
    state = [...state, session];
    await _streamReply(session);
    _busy = false;
  }

  /// Continue an existing session with a new user message.
  Future<void> sendTo(String sessionId, String userMessage) async {
    if (_busy) return;
    _busy = true;
    final session = state.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => throw StateError('Session $sessionId not found'),
    );
    session.messages.add(ChatMessage(role: 'user', content: userMessage));
    session.messages.add(ChatMessage(role: 'assistant', content: '', streaming: true));
    state = [...state]; // Trigger rebuild
    await _streamReply(session);
    _busy = false;
  }

  Future<void> _streamReply(ChatSession session) async {
    final api = _ref.read(apiClientProvider);
    final messages = session.messages
        .where((m) => !m.streaming || m.content.isNotEmpty)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    // Drop the trailing empty assistant placeholder.
    if (messages.isNotEmpty && messages.last['role'] == 'assistant') {
      messages.removeLast();
    }

    try {
      await for (final chunk in streamChatCompletion(
        dio: api.dio,
        model: 'milagro-chat',
        messages: messages.cast<Map<String, String>>(),
      )) {
        final assistant = session.messages.last;
        assistant.content += chunk;
        state = [...state]; // Trigger rebuild
      }
      session.messages.last.streaming = false;
      state = [...state];
    } catch (e) {
      session.messages.last.content += '\n\n[Error: $e]';
      session.messages.last.streaming = false;
      state = [...state];
    }
  }

  void deleteSession(String sessionId) {
    state = state.where((s) => s.id != sessionId).toList();
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, List<ChatSession>>((ref) => ChatNotifier(ref));

/// Sessions list + active chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(chatNotifierProvider);
    final notifier = ref.read(chatNotifierProvider.notifier);

    // Auto-scroll on new content.
    ref.listen(chatNotifierProvider, (prev, next) {
      if (next.length != (prev?.length ?? 0) ||
          (next.isNotEmpty &&
              next.last.messages.last.content !=
                  (prev?.isNotEmpty == true ? prev!.last.messages.last.content : ''))) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miracle Claw'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (sessions.isEmpty) _EmptyState(onStart: (msg) => notifier.startNewSession(msg)),
          if (sessions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: sessions.last.messages.length,
                itemBuilder: (ctx, i) {
                  final msg = sessions.last.messages[i];
                  return _MessageBubble(message: msg);
                },
              ),
            ),
          if (sessions.isNotEmpty) _Composer(controller: _controller, onSend: (text) async {
            if (text.trim().isEmpty) return;
            final session = sessions.last;
            await notifier.sendTo(session.id, text.trim());
            _controller.clear();
          }),
        ],
      ),
      floatingActionButton: sessions.isEmpty
          ? null
          : FloatingActionButton.small(
              onPressed: () async {
                _controller.clear();
                // Show a quick "new session" hint — for now, just prompt for first message.
                // Phase 2 polish: dedicated new-session screen with model picker.
              },
              tooltip: 'New session (send first message below)',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});
  final Future<void> Function(String) onStart;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Type a message below to talk to milagro-chat.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.auto_awesome,
                  size: 16, color: scheme.onPrimaryContainer),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.isEmpty && message.streaming
                        ? '…'
                        : message.content,
                    style: TextStyle(
                      color: isUser ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                  if (message.streaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: isUser ? scheme.onPrimary : scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.secondaryContainer,
              child: Text(
                'T',
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final Future<void> Function(String) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) return;
    final text = widget.controller.text;
    if (text.trim().isEmpty) return;
    setState(() => _busy = true);
    await widget.onSend(text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Send a message…',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
