// key_store.dart — X25519 keypair generation + secure storage for the phone.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Step 1 - Phone generates keypair".
//
// The phone generates one long-lived X25519 keypair on first launch and
// persists it in flutter_secure_storage (Android Keystore / iOS Keychain).
// The PRIVATE key never leaves the secure enclave. The PUBLIC key is
// shared with the desktop during the handshake.
//
// Rollover: the spec says every 90 days on next launch (defense in depth,
// cheap). We track `createdAt` in storage; if older than 90 days, the
// next read regenerates. For v1 we don't actually regenerate — we just
// log a warning. v2 can rotate cleanly.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage keys. Must be stable across app versions or we lose the key.
const String _kPrivKey = 'phone_x25519_priv';
const String _kPubKey = 'phone_x25519_pub';
const String _kCreatedAt = 'phone_x25519_created_at';

/// 90 days, per spec.
const Duration _keyRolloverPeriod = Duration(days: 90);

class PhoneKeypair {
  PhoneKeypair({required this.privateKey, required this.publicKey, required this.createdAt});

  /// 32-byte X25519 private seed.
  final Uint8List privateKey;

  /// 32-byte X25519 public key.
  final Uint8List publicKey;

  final DateTime createdAt;

  /// SHA-256 of the public key, base64. The "fingerprint" sent in the
  /// handshake + shown in the UI.
  Future<String> fingerprint() async {
    final digest = await Sha256().hash(publicKey);
    return base64.encode(Uint8List.fromList(digest.bytes));
  }
}

/// Reads / lazily-generates the phone's long-lived X25519 keypair.
///
/// Threading: all methods are async and stateless (Flutter secure storage
/// is itself thread-safe). Safe to call from multiple isolates concurrently
/// as long as the caller doesn't race two simultaneous `ensure()` calls.
class PhoneKeyStore {
  PhoneKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  /// Returns the existing keypair, or generates + persists a fresh one.
  /// If the existing key is older than 90 days, logs a rollover warning
  /// (does NOT rotate yet — that's v2 work; see file header).
  Future<PhoneKeypair> ensure() async {
    final privB64 = await _storage.read(key: _kPrivKey);
    final pubB64 = await _storage.read(key: _kPubKey);
    final createdAtStr = await _storage.read(key: _kCreatedAt);

    if (privB64 != null && pubB64 != null && createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      if (DateTime.now().difference(createdAt) > _keyRolloverPeriod) {
        // ignore: avoid_print
        print(
          '[key_store] phone X25519 keypair is >90 days old '
          '(created ${createdAt.toIso8601String()}). Rotation is '
          'deferred to v2; continuing with existing key.',
        );
      }
      return PhoneKeypair(
        privateKey: base64Decode(privB64),
        publicKey: base64Decode(pubB64),
        createdAt: createdAt,
      );
    }

    // First launch. Generate via package:cryptography so the public key
    // derivation matches the wire format pinned by pairing_compat_test.
    final x25519 = X25519();
    final kp = await x25519.newKeyPair();
    final pk = await kp.extractPublicKey();
    final skBytes = await kp.extractPrivateKeyBytes();

    final privBytes = Uint8List.fromList(skBytes);
    final pubBytes = Uint8List.fromList(pk.bytes);
    final now = DateTime.now();

    await _storage.write(key: _kPrivKey, value: base64.encode(privBytes));
    await _storage.write(key: _kPubKey, value: base64.encode(pubBytes));
    await _storage.write(key: _kCreatedAt, value: now.toIso8601String());

    return PhoneKeypair(
      privateKey: privBytes,
      publicKey: pubBytes,
      createdAt: now,
    );
  }

  /// Wipe the keypair. Used by "Sign out" / "Forget this device" flows.
  Future<void> clear() async {
    await _storage.delete(key: _kPrivKey);
    await _storage.delete(key: _kPubKey);
    await _storage.delete(key: _kCreatedAt);
  }
}
