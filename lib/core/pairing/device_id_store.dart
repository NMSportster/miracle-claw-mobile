// device_id_store.dart — Persisted UUID for this phone.
//
// Spec: docs/specs/mobile-desktop-pairing.md § "Step 3 - Phone initiates
// handshake". The phone sends `device_id` (UUID v4) to the desktop in
// every `/pair/initiate`. The desktop records it as the stable phone
// identity (separate from per-session ids) and uses it to:
//   - Match the same phone on re-handshake (so session state carries
//     across re-pairs).
//   - Identify the device in the "Connected devices" page (paired_devices
//     table has UNIQUE (desktop_instance_id, device_id)).
//   - Power the "Forget this phone" button on the desktop
//     (DELETE /desktops/{id}/paired-devices/{device_id}).
//
// Stored in flutter_secure_storage (same Keystore/Keychain as the
// X25519 keypair) so uninstalling the app effectively rotates it.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const String _kDeviceId = 'phone_device_id';

/// Reads / lazily-generates the phone's stable device_id (UUID v4).
///
/// One read = one write on first call. Subsequent reads return the
/// persisted value. No rotation (lost-phone revoke is the desktop's
/// job; the device_id is permanent for this install).
class DeviceIdStore {
  DeviceIdStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String> ensure() async {
    final existing = await _storage.read(key: _kDeviceId);
    if (existing != null && existing.isNotEmpty) {
      // Validate it's a UUID before returning — defends against corrupted
      // storage (e.g. partial write). Cheap.
      if (_isValidUuid(existing)) return existing;
    }
    final fresh = const Uuid().v4();
    await _storage.write(key: _kDeviceId, value: fresh);
    return fresh;
  }

  /// Wipe the device_id. Used on full Sign Out (so a different MAIC user
  /// signing in on the same device doesn't inherit this device's pairing
  /// audit trail).
  Future<void> clear() async {
    await _storage.delete(key: _kDeviceId);
  }

  bool _isValidUuid(String s) {
    // RFC 4122 UUID format: 8-4-4-4-12 hex, with version (1-7) and variant bits.
    final re = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-7][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return re.hasMatch(s);
  }
}
