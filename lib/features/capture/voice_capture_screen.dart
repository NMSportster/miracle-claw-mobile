/// Voice memo capture screen (Phase 4C).
///
/// Records raw audio on the phone → uploads to MAIC → MAIC transcribes
/// via Whisper (local, on Hetzner) → MAIC writes a `kind=voice_memo`
/// note with the transcript. Per the phone-is-a-relay rule, the phone
/// doesn't run any local model — no on-device STT.
///
/// UX:
///   - Big red "record" button toggles to "stop" when recording
///   - Live duration counter while recording
///   - After stop: preview (no playback — phone is relay, just show
///     waveform-ish duration) + "Send to MAIC" button
///   - While uploading: spinner
///   - On success: navigate to the new note's detail screen
///   - On failure: snackbar with the error, stay on this screen
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../core/capture/capture_service.dart';

class VoiceCaptureScreen extends ConsumerStatefulWidget {
  const VoiceCaptureScreen({super.key});

  @override
  ConsumerState<VoiceCaptureScreen> createState() => _VoiceCaptureScreenState();
}

class _VoiceCaptureScreenState extends ConsumerState<VoiceCaptureScreen> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _uploading = false;
  String? _error;
  String? _audioPath;
  Duration _duration = Duration.zero;
  Timer? _ticker;
  DateTime? _recordStart;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    if (_audioPath != null) {
      // Best-effort cleanup; if upload succeeded we already navigated
      // away, this is just the in-progress case.
      try { File(_audioPath!).deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() => _error = null);

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      setState(() => _error = 'Microphone permission denied.');
      return;
    }

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          // Phone is relay; bitrate doesn't need to be high (Whisper
          // re-encodes to 16kHz mono anyway). 64kbps keeps upload fast.
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: 'voice_memo_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      // After start() resolves, the recorder is active and writing to
      // the path we provided. We have no Future<String?> return to
      // await; the path is what we asked for.
      _recordStart = DateTime.now();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted || _recordStart == null) return;
        setState(() {
          _duration = DateTime.now().difference(_recordStart!);
        });
      });
      setState(() {
        _recording = true;
        _audioPath = 'voice_memo_${_recordStart!.millisecondsSinceEpoch}.m4a';
        _duration = Duration.zero;
      });
    } catch (e) {
      setState(() => _error = 'Recorder error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _ticker?.cancel();
      final path = await _recorder.stop();  // Future<String?>
      if (!mounted) return;
      setState(() {
        _recording = false;
        if (path != null) _audioPath = path;
      });
    } catch (e) {
      setState(() {
        _recording = false;
        _error = 'Stop error: $e';
      });
    }
  }

  Future<void> _send() async {
    final path = _audioPath;
    if (path == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    final svc = ref.read(captureServiceProvider);
    final result = await svc.uploadVoiceMemo(File(path));
    if (!mounted) return;
    setState(() => _uploading = false);
    if (result.isOk) {
      final noteId = result.note!.noteId;
      // Done — clean up the temp file + navigate to the new note.
      try { File(path).deleteSync(); } catch (_) {}
      _audioPath = null;
      context.go('/workspace/$noteId');
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voice memo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatDuration(_duration),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _recording
                    ? 'Recording… tap stop when done'
                    : (_audioPath == null
                        ? 'Tap to record'
                        : 'Ready to send'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              _RecordButton(
                recording: _recording,
                uploading: _uploading,
                onStart: _startRecording,
                onStop: _stopRecording,
              ),
              const SizedBox(height: 24),
              if (_uploading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Uploading + transcribing on MAIC…'),
                    ],
                  ),
                )
              else if (_audioPath != null && !_recording)
                FilledButton.icon(
                  onPressed: _send,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Send to MAIC'),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              Text(
                'Voice is transcribed by MAIC (Whisper) and stored as a '
                'note. Audio is not kept after transcription.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.recording,
    required this.uploading,
    required this.onStart,
    required this.onStop,
  });
  final bool recording;
  final bool uploading;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final disabled = uploading;
    return GestureDetector(
      onTap: disabled ? null : (recording ? onStop : onStart),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: disabled
              ? Theme.of(context).colorScheme.outlineVariant
              : (recording
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary),
          boxShadow: [
            if (recording)
              BoxShadow(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 8,
              ),
          ],
        ),
        child: Icon(
          recording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}
