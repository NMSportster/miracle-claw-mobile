/// Photo OCR capture screen (Phase 4C).
///
/// Takes a photo (camera or gallery) → uploads raw image bytes to MAIC
/// → MAIC runs Tesseract → MAIC writes a `kind=photo_ocr` note with the
/// extracted text. Per the phone-is-a-relay rule, the phone doesn't run
/// any local OCR model.
///
/// Use cases: receipts, business cards, whiteboards, handwritten notes,
/// screenshots of "stuff you want to remember as text".
///
/// UX:
///   - "Take photo" button (camera intent) + "Pick from gallery" button
///   - Preview the picked image full-width
///   - "Send to MAIC" button
///   - On success: navigate to the new note's detail screen
///   - On failure: snackbar with the error
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/capture/capture_service.dart';

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  final _picker = ImagePicker();
  XFile? _picked;
  bool _uploading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);

    if (source == ImageSource.camera) {
      // Camera intent handles its own permission prompt via the OS, but
      // we ask up front so the user gets a clear denial UI rather than
      // a silent fail.
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        setState(() => _error = 'Camera permission denied.');
        return;
      }
    }
    // Gallery doesn't need a runtime permission on modern Android/iOS.

    try {
      final file = await _picker.pickImage(
        source: source,
        // High resolution is wasted: Tesseract downsamples internally.
        // Cap at 2000px on the long edge — keeps uploads fast.
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (file == null) {
        // User cancelled the picker. Stay silent.
        return;
      }
      setState(() => _picked = file);
    } catch (e) {
      setState(() => _error = 'Picker error: $e');
    }
  }

  Future<void> _send() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final svc = ref.read(captureServiceProvider);
    final result = await svc.uploadPhoto(File(picked.path));
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.isOk) {
      final noteId = result.note!.noteId;
      context.go('/workspace/$noteId');
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo OCR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _picked == null
                    ? _EmptyState(onPickCamera: () => _pick(ImageSource.camera),
                                  onPickGallery: () => _pick(ImageSource.gallery))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_picked!.path),
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (_picked != null && !_uploading)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _picked = null),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retake'),
                      ),
                    ),
                  if (_picked != null && !_uploading) const SizedBox(width: 12),
                  if (_uploading)
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Uploading + OCR on MAIC…'),
                        ],
                      ),
                    )
                  else if (_picked != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _send,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Send to MAIC'),
                      ),
                    )
                  else
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Photo is OCR\'d by MAIC (Tesseract) and stored as text in '
                'a note. Image is not kept after OCR.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPickCamera, required this.onPickGallery});
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Capture text from anywhere',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Receipts, business cards, whiteboards, screenshots. '
              'MAIC reads the text so you can search it later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onPickGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Gallery'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: onPickCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
