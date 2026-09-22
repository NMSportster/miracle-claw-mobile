/// Quick capture screen (Phase 4C, roadmap item 16).
///
/// Minimal form for "just remember this" notes. Title-only by default;
/// details are optional and tucked behind a "More" expander so the
/// common case is one tap + type + send.
///
/// Differences from `workspace_create_screen.dart`:
///   - Title autofocuses immediately
///   - No kind selector (always `kind=message` — phone-direct notes
///     don't need the desktop to act on them, this is just a memo)
///   - Optional details hidden behind "Add details" expander
///   - Tap "Send" hits Enter / keyboard submit, no scrolling
///
/// This screen also serves as the Android Quick Tile target for v1:
/// the tile launches directly here with `kind=quick` so the user can
/// capture in <5s from anywhere.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/workspace/workspace_providers.dart';

class QuickCaptureScreen extends ConsumerStatefulWidget {
  const QuickCaptureScreen({super.key});

  @override
  ConsumerState<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends ConsumerState<QuickCaptureScreen> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  bool _showDetails = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Autofocus title so the user can type immediately. If invoked from
    // the Quick Tile while the app was backgrounded, this still works.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type something first.')),
      );
      return;
    }
    setState(() => _submitting = true);

    final noteId = _freshNoteId();
    final result = await writeSubkey(
      ref,
      noteId: noteId,
      subkey: 'request',
      value: {
        'kind': 'message',
        'title': title,
        'text': _textCtrl.text.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'source': 'quick_capture',
        'needs_approval_for': <String>[],
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case MutationOk():
        // Vibrate briefly to confirm capture (haptic is v2; for now we
        // dismiss back). The user lands on Tasks list where the new note
        // shows at the top.
        HapticFeedback.lightImpact();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/workspace');
        }
      case MutationQuotaExceeded(:final error):
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Workspace full'),
            content: Text(
              'You\'ve used ${(error.usedBytes / 1024 / 1024).toStringAsFixed(1)} MB '
              'of your ${(error.quotaBytes / 1024 / 1024).toStringAsFixed(0)} MB '
              '${error.tier} quota. Delete some old tasks first.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      case MutationError(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $error')),
        );
    }
  }

  /// Generate a UUIDv4-like identifier. Mirrors workspace_create_screen.
  String _freshNoteId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick capture'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 22),
                ),
                style: const TextStyle(fontSize: 22),
                textInputAction: _showDetails
                    ? TextInputAction.newline
                    : TextInputAction.send,
                onSubmitted: (_) => _submit(),
                maxLines: null,
                maxLength: 200,
              ),
              const SizedBox(height: 8),
              if (!_showDetails)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showDetails = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Add details'),
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Optional details',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    maxLength: 4000,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
