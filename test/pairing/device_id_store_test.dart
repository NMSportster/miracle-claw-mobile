// device_id_store_test.dart — Unit tests for DeviceIdStore.
//
// v1 scope: persistence + regeneration. Uses an in-memory mock of
// FlutterSecureStorage so we don't need a real keystore.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:miracle_claw_mobile/core/pairing/device_id_store.dart';

/// Minimal in-memory replacement for FlutterSecureStorage. The real
/// package hits a platform channel we don't have in pure unit tests.
class _MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    _store.remove(key);
  }

  // Unused methods — stub for the interface.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  group('DeviceIdStore', () {
    test('ensure() generates a v4 UUID on first call', () async {
      final store = DeviceIdStore(storage: _MockSecureStorage());
      final id = await store.ensure();
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(re.hasMatch(id), true,
          reason: 'expected a v4 UUID, got "$id"');
    });

    test('ensure() returns the same id on subsequent calls (persisted)',
        () async {
      final store = DeviceIdStore(storage: _MockSecureStorage());
      final first = await store.ensure();
      final second = await store.ensure();
      expect(second, first);
    });

    test('clear() removes the persisted id; ensure() generates fresh', () async {
      final store = DeviceIdStore(storage: _MockSecureStorage());
      final first = await store.ensure();
      await store.clear();
      final second = await store.ensure();
      expect(second, isNot(first));
    });

    test('ensure() rejects a corrupted stored value and regenerates', () async {
      final mock = _MockSecureStorage();
      await mock.write(key: 'phone_device_id', value: 'not-a-uuid');
      final store = DeviceIdStore(storage: mock);
      final id = await store.ensure();
      // Fresh UUID, not the corrupted one.
      expect(id, isNot('not-a-uuid'));
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(re.hasMatch(id), true);
    });
  });
}
