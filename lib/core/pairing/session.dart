// session.dart — In-memory session state for a paired phone.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Handshake protocol" Step 5
// and § "Subsequent requests".
//
// The session_secret is the symmetric key the phone uses to HMAC-sign
// every request to the desktop. It lives in process memory only — never
// on disk. The on-disk file (which we don't write on the phone side;
// the desktop's paired_sessions.json handles that) only contains a
// fingerprint of the secret.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// What the phone remembers after a successful handshake.
///
/// `instanceId` identifies the desktop (survives restarts).
/// `sessionId` identifies this particular pairing session (changes on
/// revoke + re-handshake).
class PairSession {
  PairSession({
    required this.sessionId,
    required this.sessionSecret,
    required this.instanceId,
    required this.instanceName,
    required this.endpoint,
    required this.endpointKind,
    required this.capabilities,
    required this.expiresAt,
  });

  /// UUID assigned by the desktop. Identifies this session.
  final String sessionId;

  /// 32-byte secret shared with the desktop. NEVER serialized.
  final Uint8List sessionSecret;

  /// Desktop's stable ID. Phone uses this as a key suffix in secure storage.
  final String instanceId;

  /// Display name (e.g. "David's MacBook Pro").
  final String instanceName;

  /// Best-known base URL for this desktop
  /// (e.g. "http://192.168.1.50:28789" or "https://relay.maicserver.com").
  final String endpoint;

  /// 'lan' | 'tailnet' | 'relay'
  final String endpointKind;

  /// Capability strings the desktop granted us
  /// (e.g. ["chat", "sessions:rw", "filesystem:read_file"]).
  final List<String> capabilities;

  /// When this session expires. Phone re-handshakes before this time.
  final DateTime expiresAt;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);

  /// True if this session can request the named capability. The desktop
  /// also enforces this per-request — the phone-side check is for UX
  /// (don't show "Files" tab if the session can't read files).
  bool can(String capability) => capabilities.contains(capability);
}

/// Compute the HMAC-SHA256 signature that goes in
/// `X-Miracle-Pair-Session: <session_id>:<hmac>`.
///
/// Body bytes = the exact bytes that will be sent on the wire. For GET
/// requests with no body, pass `Uint8List(0)`.
///
/// Spec § "Subsequent requests": `hmac_sha256(session_secret, body)`.
Future<String> signRequestBody({
  required PairSession session,
  required Uint8List body,
}) async {
  final hmac = Hmac.sha256();
  final mac = await hmac.calculateMac(
    body,
    secretKey: SecretKey(session.sessionSecret),
  );
  return base64.encode(Uint8List.fromList(mac.bytes));
}
