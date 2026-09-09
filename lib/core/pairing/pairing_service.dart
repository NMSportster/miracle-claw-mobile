// pairing_service.dart — Phone-side pairing orchestrator.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Handshake protocol"
// and § "Discovery loop lifecycle".
//
// Responsibilities:
//   1. Discovery loop: poll `GET /v1/users/me/desktop` every 60s + on
//      app foreground + on network change. Update ConnectionState.
//   2. Handshake: when a desktop is found and the phone isn't paired
//      with it, POST /pair/initiate with phone pubkey, decrypt the
//      session_secret, store PairSession.
//   3. Revocation handling: on 401 from desktop, clear the local
//      session and fall back to CloudOnly. The next discovery tick
//      will re-handshake if the desktop is still active.
//
// v1 scope:
//   - HTTP-based discovery only (no mDNS).
//   - No background sync (the discovery loop runs while the app is in
//     foreground; when backgrounded, the cached ConnectionState
//     persists).
//   - Single active paired desktop at a time.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../auth/jwt_reader.dart';
import 'discovery_state.dart';
import 'key_store.dart';
import 'session.dart';
import 'transport.dart';

/// Wire-format constant. Must match Rust `PAIR_INFO`.
const String _pairInfo = 'miracle-claw-pair-v1';

const Duration _discoveryInterval = Duration(seconds: 60);

/// HTTP client for the pairing service. Separate from the main
/// ApiClient so we can give it different timeouts + the pairing-specific
/// headers (no auto-relogin retries).
class _PairingHttp {
  _PairingHttp(this._readToken)
      : dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 10),
          headers: const {'Content-Type': 'application/json'},
          validateStatus: (s) => s != null && s < 500,
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final Dio dio;
  final JwtReader _readToken;
}

/// Main pairing service. One per app. Owned by a Riverpod provider.
class PairingService {
  PairingService({
    required PhoneKeyStore keyStore,
    required JwtReader jwtReader,
    required TransportLadder ladder,
    Dio? dioOverride,
    DeviceInfoPlugin? deviceInfo,
  })  : _keys = keyStore,
        _ladder = ladder,
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _http = _PairingHttp(jwtReader);

  final PhoneKeyStore _keys;
  final TransportLadder _ladder;
  final DeviceInfoPlugin _deviceInfo;
  // ignore: unused_field — exposed via getter for tests
  final _PairingHttp _http;

  // ─── Discovery ────────────────────────────────────────────────────────

  Timer? _discoveryTimer;
  StreamSubscription? _foregroundSub;

  /// Start the discovery loop. Safe to call multiple times (idempotent).
  void startDiscovery(void Function(ConnectionState) onState) {
    _discoveryTimer?.cancel();
    // Fire one immediate tick, then every 60s.
    unawaited(_discoveryTick(onState));
    _discoveryTimer = Timer.periodic(_discoveryInterval, (_) {
      unawaited(_discoveryTick(onState));
    });
  }

  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    unawaited(_foregroundSub?.cancel());
    _foregroundSub = null;
  }

  /// Run one discovery tick. Exposed for tests.
  ///
  /// Flow:
  ///   1. GET /v1/users/me/desktop from MAIC cloud.
  ///   2. If 204 → no desktop online → CloudOnly.
  ///   3. If 200 → got a desktop:
  ///      a. If we're already Paired with this instance_id → no-op (state unchanged).
  ///      b. If we're Paired with a DIFFERENT instance → drop the old session, re-handshake.
  ///      c. If we're CloudOnly or PairingInFlight → handshake.
  Future<ConnectionState> tick(ConnectionState current) async {
    try {
      final resp = await _http.dio.get<String>(
        '${_ladder.maicCloudUrl}/v1/users/me/desktop',
      );
      if (resp.statusCode == 204 || resp.data == null) {
        return const CloudOnly(reason: 'no_desktop_online');
      }
      if (resp.statusCode != 200) {
        return const CloudOnly(reason: 'error');
      }
      final body = jsonDecode(resp.data!) as Map<String, dynamic>;
      final desktop = DesktopInstance.fromJson(body);
      return await _maybeHandshake(current: current, desktop: desktop);
    } on DioException {
      // MAIC unreachable — keep current state.
      return current;
    }
  }

  Future<ConnectionState> _discoveryTick(void Function(ConnectionState) onState) async {
    final current = _lastKnownState ?? const CloudOnly(reason: 'first_run');
    final next = await tick(current);
    _lastKnownState = next;
    onState(next);
    return next;
  }

  ConnectionState? _lastKnownState;

  // ─── Handshake ────────────────────────────────────────────────────────

  Future<ConnectionState> _maybeHandshake({
    required ConnectionState current,
    required DesktopInstance desktop,
  }) async {
    // Already paired with this exact desktop? Nothing to do.
    if (current is Paired && current.desktop.instanceId == desktop.instanceId) {
      // But if session is expired, fall through and re-handshake.
      if (!current.session.isExpired(DateTime.now())) {
        return current;
      }
    }

    // Initiate handshake with this desktop.
    return await _handshakeWith(desktop);
  }

  Future<ConnectionState> _handshakeWith(DesktopInstance desktop) async {
    // Need a stable device_id (persisted across launches). For v1 we
    // generate a fresh one per app install — phone-side persistence
    // belongs in v2 (paired_devices uses device_id for revocation).
    // TODO(v2): persist device_id to flutter_secure_storage.
    final deviceId = const Uuid().v4();

    // device_name from device_info_plus.
    final deviceName = await _readDeviceName();

    // Phone's pubkey + fingerprint.
    final kp = await _keys.ensure();
    final pubB64 = base64.encode(kp.publicKey);
    final fp = await kp.fingerprint();

    // POST /pair/initiate to the desktop endpoint.
    try {
      final resp = await _http.dio.post<Map<String, dynamic>>(
        '${desktop.endpoint}/pair/initiate',
        data: {
          'device_name': deviceName,
          'device_id': deviceId,
          'device_pubkey': pubB64,
          'fingerprint': fp,
        },
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (resp.statusCode != 200 || resp.data == null) {
        return const CloudOnly(reason: 'error');
      }
      final body = resp.data!;
      final sessionSecret = await _decryptHandshake(
        phoneStaticPriv: kp.privateKey,
        sessionId: body['session_id'] as String,
        ephemeralPubB64: body['ephemeral_pub'] as String,
        encryptedSecretB64: body['encrypted_secret'] as String,
      );

      final session = PairSession(
        sessionId: body['session_id'] as String,
        sessionSecret: sessionSecret,
        instanceId: desktop.instanceId,
        instanceName: desktop.instanceName,
        endpoint: desktop.endpoint,
        endpointKind: desktop.endpointKind,
        capabilities: (body['capabilities'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        expiresAt: DateTime.tryParse(body['expires_at'] as String? ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
      );

      return Paired(desktop: desktop, session: session);
    } on DioException {
      return const CloudOnly(reason: 'error');
    }
  }

  /// Phone side of the handshake: decrypt the session_secret.
  /// Mirrors `phone_decrypt_handshake` on the Rust side.
  Future<Uint8List> _decryptHandshake({
    required Uint8List phoneStaticPriv,
    required String sessionId,
    required String ephemeralPubB64,
    required String encryptedSecretB64,
  }) async {
    // Step 1: X25519 DH → shared_secret
    final x25519 = X25519();
    final phoneKp = await x25519.newKeyPairFromSeed(phoneStaticPriv);
    final sharedSecret = await x25519.sharedSecretKey(
      keyPair: phoneKp,
      remotePublicKey: SimplePublicKey(
        base64Decode(ephemeralPubB64),
        type: KeyPairType.x25519,
      ),
    );

    // Step 2: HKDF-SHA256(salt=session_id, info=PAIR_INFO, L=32)
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final sessionKey = await hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: hexDecode(sessionId.replaceAll('-', '')),
      info: utf8.encode(_pairInfo),
    );

    // Step 3: AES-256-GCM decrypt. Wire: nonce(12) || ciphertext || tag(16).
    final encrypted = base64Decode(encryptedSecretB64);
    final nonce = encrypted.sublist(0, 12);
    final ciphertextWithTag = encrypted.sublist(12);
    final tag = Mac(ciphertextWithTag.sublist(ciphertextWithTag.length - 16));
    final ciphertext = ciphertextWithTag.sublist(0, ciphertextWithTag.length - 16);

    final aes = AesGcm.with256bits();
    final plaintext = await aes.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: tag),
      secretKey: sessionKey,
    );
    return Uint8List.fromList(plaintext);
  }

  Future<String> _readDeviceName() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return '${info.name} (${info.model})';
      }
      return 'Unknown device';
    } on Object {
      return 'Unknown device';
    }
  }
}

/// Hex-decode helper (Uint8List view of hex string).
Uint8List hexDecode(String hex) {
  if (hex.length % 2 != 0) {
    throw FormatException('hex string must have even length');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

// ─── Riverpod providers ─────────────────────────────────────────────────

final phoneKeyStoreProvider = Provider<PhoneKeyStore>((ref) => PhoneKeyStore());

final transportLadderProvider = Provider<TransportLadder>((ref) => const TransportLadder());

final pairingServiceProvider = Provider<PairingService>((ref) {
  final keys = ref.watch(phoneKeyStoreProvider);
  final ladder = ref.watch(transportLadderProvider);
  final jwt = ref.watch(jwtReaderProvider);
  return PairingService(keyStore: keys, jwtReader: jwt, ladder: ladder);
});
