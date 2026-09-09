// discovery_state.dart — Riverpod state machine for phone ↔ desktop pairing.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Riverpod state machine".
//
// The phone is always in exactly one of these states. The state
// determines the API baseUrl (cloud MAIC vs paired desktop) and the
// "Connected Devices" UI affordances.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session.dart';

/// Minimal info about a paired desktop — enough for the phone to
/// attempt pairing + show in Settings.
class DesktopInstance {
  const DesktopInstance({
    required this.instanceId,
    required this.instanceName,
    required this.endpoint,
    required this.endpointKind,
    required this.fingerprint,
    required this.publicKey,
    required this.lastHeartbeatAt,
  });

  final String instanceId;
  final String instanceName;
  final String endpoint;
  final String endpointKind; // 'lan' | 'tailnet' | 'relay'
  final String fingerprint;
  final String publicKey; // base64
  final DateTime lastHeartbeatAt;

  factory DesktopInstance.fromJson(Map<String, dynamic> json) {
    return DesktopInstance(
      instanceId: json['instance_id'] as String,
      instanceName: json['instance_name'] as String? ?? 'Unknown desktop',
      endpoint: json['endpoint'] as String? ?? '',
      endpointKind: json['endpoint_kind'] as String? ?? 'relay',
      fingerprint: json['fingerprint'] as String? ?? '',
      publicKey: json['public_key'] as String? ?? '',
      lastHeartbeatAt: DateTime.tryParse(json['last_heartbeat_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Sealed base for the phone's pairing state.
sealed class ConnectionState {
  const ConnectionState();
}

/// Phone has no paired desktop (yet).
class CloudOnly extends ConnectionState {
  const CloudOnly({required this.reason});
  final String reason; // 'no_desktop_online' | 'first_run' | 'revoked' | 'error'
}

/// Phone is paired with a desktop.
class Paired extends ConnectionState {
  const Paired({required this.desktop, required this.session});
  final DesktopInstance desktop;
  final PairSession session;
}

/// Phone is in the middle of (re-)pairing.
class PairingInFlight extends ConnectionState {
  const PairingInFlight({required this.desktop});
  final DesktopInstance desktop;
}

/// Riverpod provider for the connection state.
final connectionStateProvider = StateProvider<ConnectionState>(
  (ref) => const CloudOnly(reason: 'first_run'),
);
