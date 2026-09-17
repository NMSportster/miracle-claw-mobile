/// Create a new note — the simplest possible flow.
///
/// Just collects a title + free-form text, then PUTs them as the
/// "request" subkey of a fresh note_id (UUID v4). The desktop sees it
/// on its end and acts on it.
///
/// Future phases may add: kind selector, attachment picker, scheduled
/// send, approval-required checkboxes. For now, keep it short.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/workspace/workspace_providers.dart';

class WorkspaceCreateScreen extends ConsumerStatefulWidget {
  const WorkspaceCreateScreen({super.key});

  @override
  ConsumerState<WorkspaceCreateScreen> createState() => _WorkspaceCreateScreenState();
}

class _WorkspaceCreateScreenState extends ConsumerState<WorkspaceCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
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
        'text': text,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'needs_approval_for': <String>[],
      },
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case MutationOk():
        context.pop();
      case MutationQuotaExceeded(:final error):
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Workspace full'),
            content: Text(
              'You\'ve used ${(error.usedBytes / 1024 / 1024).toStringAsFixed(1)} MB '
              'of your ${(error.quotaBytes / 1024 / 1024).toStringAsFixed(0)} MB '
              '${error.tier} quota. Delete some old tasks or upgrade your plan.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      case MutationError(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $error')),
        );
    }
  }

  /// Generate a fresh UUIDv4-ish identifier (lowercase hex, no dashes).
  /// The MAIC backend canonicalizes it through Python's uuid.UUID(), so we
  /// could also send a dashed UUID. We use the no-dash form because it
  /// matches the existing pairing code on the desktop side.
  String _freshNoteId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // RFC 4122 v4 + variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New task'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Send'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              maxLength: 200,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
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
    );
  }
}
