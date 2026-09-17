// connected_devices_screen.dart — Settings → Connected Devices.
//
// @deprecated 2026-09-16: replaced by the MAIC per-user workspace model.
// The pairing flow is no longer the primary mechanism for phone↔desktop
// communication — that's now via MAIC's per-user workspace endpoints
// (see lib/core/workspace/ and lib/features/workspace/). This file is
// kept in git history per David's instruction ("we may need it later")
// but is no longer routed to from anywhere in the app. See
// memory/projects/workspace_architecture.md for the new model.
//
// Spec (legacy): docs/specs/mobile-desktop-pairing.md § "Settings → Connected
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
    // Phase 3.2b: tell the desktop to revoke us (best-effort), then
    // clear local state. If the desktop is unreachable, we still clear
    // local — the user wanted to sign out, so don't hold them hostage
    // waiting for a server round-trip.
    final svc = ref.read(pairingServiceProvider);
    final revoked = await svc.revokePairedDesktop(state.session);

    ref.read(connectionStateProvider.notifier).state =
        const CloudOnly(reason: 'revoked');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(revoked
              ? 'Signed out of ${state.desktop.instanceName}.'
              : 'Signed out locally of ${state.desktop.instanceName}. Desktop unreachable — server revoke will expire naturally.'),
        ),
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
