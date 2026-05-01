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
  late _FakeDriver kasaDriver;
  late _FakeDriver cyncDriver;

  setUp(() {
    manager = DriverManager();
    kasaDriver = _FakeDriver('kasa');
    cyncDriver = _FakeDriver('cync');
    manager.registerDriver(kasaDriver);
    manager.registerDriver(cyncDriver);
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

    test('toggle routes to the correct driver', () async {
      await manager.toggle('kasa-cmd', true);
      expect(kasaDriver.lastToggleValue, isTrue);
    });

    test('setBrightness routes to the correct driver', () async {
      await manager.setBrightness('kasa-cmd', 0.5);
      expect(kasaDriver.lastBrightness, closeTo(0.5, 0.001));
    });

    test('getPowerStatus reflects last toggle', () async {
      await manager.toggle('kasa-cmd', true);
      final status = await manager.getPowerStatus('kasa-cmd');
      expect(status, isTrue);
    });

    test('throws StateError if device is not bound', () {
      expect(
        () => manager.toggle('not-bound-id', true),
        throwsA(isA<StateError>()),
      );
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
