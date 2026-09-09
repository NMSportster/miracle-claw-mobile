// connected_devices_screen.dart — Settings → Connected Devices.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Settings → Connected
// Devices page".
//
// v1 shows:
//   - Current ConnectionState (paired / cloud-only / pairing)
//   - Paired desktop name + OS + last heartbeat
//   - "Pair a different desktop" — kicks the discovery loop for 30s
//   - "Sign out of [desktop name]" — clears local session (the desktop
//     is told via mc_revoke_device if reachable; out of scope for v1)
//
// No QR UI. The spec is explicit: pairing happens automatically once
// both apps are installed and the user is logged in to MAIC.

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pairing/discovery_state.dart';
import '../../core/pairing/pairing_service.dart';

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends ConsumerState<ConnectedDevicesScreen> {
  bool _scanning = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connected Devices')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(state: state),
          const SizedBox(height: 16),
          _ActionSection(
            scanning: _scanning,
            onScan: _scan,
            onForget: state is Paired ? () => _forget(state) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final svc = ref.read(pairingServiceProvider);
    final current = ref.read(connectionStateProvider);
    final next = await svc.tick(current);
    if (mounted) {
      ref.read(connectionStateProvider.notifier).state = next;
      setState(() => _scanning = false);
    }
  }

  Future<void> _forget(Paired state) async {
    // v1: just clear the local ConnectionState. v2: also call
    // mc_revoke_device on the desktop to invalidate the session there.
    ref.read(connectionStateProvider.notifier).state =
        const CloudOnly(reason: 'revoked');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed out of ${state.desktop.instanceName}.')),
      );
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});
  final ConnectionState state;

  static const _reasonFirstRun = 'first_run';
  static const _reasonNoDesktop = 'no_desktop_online';
  static const _reasonRevoked = 'revoked';

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle, color) = switch (state) {
      CloudOnly(reason: final reason) => (
        Icons.cloud_outlined,
        'No desktop paired',
        switch (reason) {
          _reasonFirstRun => 'Sign in to MAIC and install Miracle Claw Desktop to pair automatically.',
          _reasonNoDesktop => 'Your desktop is not currently online. Requests will go through cloud MAIC.',
          _reasonRevoked => 'You signed out of your last paired desktop.',
          _ => 'Pairing unavailable — please try again.',
        },
        Colors.grey,
      ),
      PairingInFlight(:final desktop) => (
        Icons.sync,
        'Pairing with ${desktop.instanceName}…',
        'Handshake in progress. This usually takes <1s.',
        Colors.blue,
      ),
      Paired(:final desktop) => (
        Icons.laptop_mac,
        desktop.instanceName,
        '${desktop.endpointKind.toUpperCase()} · ${desktop.endpoint}',
        Colors.green,
      ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 36),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.scanning, required this.onScan, this.onForget});
  final bool scanning;
  final VoidCallback onScan;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: scanning ? null : onScan,
          icon: scanning
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(scanning ? 'Scanning…' : 'Pair a different desktop'),
        ),
        const SizedBox(height: 8),
        if (onForget != null)
          OutlinedButton.icon(
            onPressed: onForget,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out of paired desktop'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
      ],
    );
  }
}
