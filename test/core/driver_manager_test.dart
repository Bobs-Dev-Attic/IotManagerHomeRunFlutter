import 'package:flutter_test/flutter_test.dart';

import 'package:iot_manager/core/base/base_device_driver.dart';
import 'package:iot_manager/core/drivers/driver_manager.dart';
import 'package:iot_manager/core/models/device_model.dart';
import 'package:iot_manager/core/models/driver_config.dart';

// ---------------------------------------------------------------------------
// Fakes / Mocks
// ---------------------------------------------------------------------------

class _FakeDriver extends BaseDeviceDriver {
  _FakeDriver(this._id);

  final String _id;
  bool? lastToggleValue;
  double? lastBrightness;
  bool _poweredOn = false;
  bool _initialized = false;

  @override
  String get driverId => _id;

  @override
  String get displayName => 'Fake $_id Driver';

  @override
  List<DriverConfigField> get configSchema => const [];

  @override
  _FakeDriver clone() => _FakeDriver(_id);

  @override
  Future<void> initialize(DeviceModel device, Map<String, dynamic> config) async {
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
  }

  @override
  Future<void> toggle(bool value) async {
    lastToggleValue = value;
    _poweredOn = value;
  }

  @override
  Future<void> setBrightness(double brightness) async {
    lastBrightness = brightness;
  }

  @override
  Future<void> setColorTemperature(int kelvin) async {}

  @override
  Future<void> setColor(int r, int g, int b) async {}

  @override
  Future<bool> getPowerStatus() async => _poweredOn;

  @override
  Future<double?> getBrightness() async => lastBrightness;

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async => {'driverId': _id};
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeviceModel _makeDevice(DeviceBrand brand, String id) => DeviceModel(
      deviceId: id,
      userId: 'u1',
      displayName: 'Test $id',
      brand: brand,
      type: DeviceType.smartPlug,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late DriverManager manager;

  setUp(() {
    manager = DriverManager();
    manager.registerDriver(_FakeDriver('kasa'));
    manager.registerDriver(_FakeDriver('cync'));
  });

  group('DriverManager — registration', () {
    test('registers drivers by driverId', () {
      final ids = manager.registeredDrivers.map((d) => d.driverId).toList();
      expect(ids, containsAll(['kasa', 'cync']));
    });

    test('overwriting a driver replaces the previous one', () {
      final newKasa = _FakeDriver('kasa');
      manager.registerDriver(newKasa);
      // Still only one driver per id.
      final kasas = manager.registeredDrivers
          .where((d) => d.driverId == 'kasa')
          .toList();
      expect(kasas.length, equals(1));
    });
  });

  group('DriverManager — bindDevice / unbindDevice', () {
    test('binds a kasa device successfully', () async {
      final device = _makeDevice(DeviceBrand.kasa, 'kasa-1');
      await manager.bindDevice(device);
      expect(manager.isBound('kasa-1'), isTrue);
    });

    test('binds a cync device successfully', () async {
      final device = _makeDevice(DeviceBrand.cync, 'cync-1');
      await manager.bindDevice(device);
      expect(manager.isBound('cync-1'), isTrue);
    });

    test('throws DriverInitException for unknown brand', () async {
      final device = _makeDevice(DeviceBrand.unknown, 'unknown-1');
      // 'unknown' driver is not registered.
      expect(
        () => manager.bindDevice(device),
        throwsA(isA<DriverInitException>()),
      );
    });

    test('unbind removes device', () async {
      final device = _makeDevice(DeviceBrand.kasa, 'kasa-2');
      await manager.bindDevice(device);
      await manager.unbindDevice('kasa-2');
      expect(manager.isBound('kasa-2'), isFalse);
    });
  });

  group('DriverManager — command routing', () {
    late DeviceModel kasaDevice;

    setUp(() async {
      kasaDevice = _makeDevice(DeviceBrand.kasa, 'kasa-cmd');
      await manager.bindDevice(kasaDevice);
    });

    test('toggle on updates power status', () async {
      await manager.toggle('kasa-cmd', true);
      final status = await manager.getPowerStatus('kasa-cmd');
      expect(status, isTrue);
    });

    test('toggle off updates power status', () async {
      await manager.toggle('kasa-cmd', true);
      await manager.toggle('kasa-cmd', false);
      final status = await manager.getPowerStatus('kasa-cmd');
      expect(status, isFalse);
    });

    test('setBrightness is reflected by getBrightness', () async {
      await manager.setBrightness('kasa-cmd', 0.5);
      final brightness = await manager.getBrightness('kasa-cmd');
      expect(brightness, closeTo(0.5, 0.001));
    });

    test('throws StateError if device is not bound', () {
      expect(
        () => manager.toggle('not-bound-id', true),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('DriverManager — driver isolation (clone)', () {
    test('two devices of the same brand have independent state', () async {
      final d1 = _makeDevice(DeviceBrand.kasa, 'kasa-a');
      final d2 = _makeDevice(DeviceBrand.kasa, 'kasa-b');
      await manager.bindDevice(d1);
      await manager.bindDevice(d2);

      await manager.toggle('kasa-a', true);
      await manager.toggle('kasa-b', false);

      expect(await manager.getPowerStatus('kasa-a'), isTrue);
      expect(await manager.getPowerStatus('kasa-b'), isFalse);
    });
  });

  group('DriverManager — disposeAll', () {
    test('disposes all bound drivers', () async {
      final d1 = _makeDevice(DeviceBrand.kasa, 'k1');
      final d2 = _makeDevice(DeviceBrand.cync, 'c1');
      await manager.bindDevice(d1);
      await manager.bindDevice(d2);
      await manager.disposeAll();
      expect(manager.isBound('k1'), isFalse);
      expect(manager.isBound('c1'), isFalse);
    });
  });
}
