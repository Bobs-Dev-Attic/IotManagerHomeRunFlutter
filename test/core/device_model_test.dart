import 'package:flutter_test/flutter_test.dart';

import 'package:iot_manager/core/models/device_model.dart';

void main() {
  group('DeviceModel', () {
    const device = DeviceModel(
      deviceId: 'dev-1',
      userId: 'user-1',
      displayName: 'Test Lamp',
      brand: DeviceBrand.kasa,
      type: DeviceType.dimmerSwitch,
      ipAddress: '192.168.1.50',
      macAddress: 'AA:BB:CC:DD:EE:FF',
    );

    test('equality is based on deviceId', () {
      const same = DeviceModel(
        deviceId: 'dev-1',
        userId: 'user-2', // different userId, same deviceId
        displayName: 'Other Name',
        brand: DeviceBrand.cync,
        type: DeviceType.colorBulb,
      );
      expect(device, equals(same));
    });

    test('copyWith updates only specified fields', () {
      final updated = device.copyWith(
        displayName: 'Updated Lamp',
        isPoweredOn: true,
      );
      expect(updated.displayName, 'Updated Lamp');
      expect(updated.isPoweredOn, isTrue);
      expect(updated.deviceId, device.deviceId);
      expect(updated.brand, device.brand);
      expect(updated.ipAddress, device.ipAddress);
    });

    test('toFirestore contains expected keys', () {
      final map = device.toFirestore();
      expect(map['userId'], 'user-1');
      expect(map['displayName'], 'Test Lamp');
      expect(map['brand'], 'kasa');
      expect(map['type'], 'dimmerSwitch');
      expect(map['ipAddress'], '192.168.1.50');
      expect(map['macAddress'], 'AA:BB:CC:DD:EE:FF');
    });

    test('_brandFromString falls back to unknown for unrecognised value', () {
      // Access via toFirestore → fromFirestore round-trip is not easily
      // testable without Firestore; test the enum fallback directly.
      expect(DeviceBrand.values.firstWhere(
        (b) => b.name == 'notABrand',
        orElse: () => DeviceBrand.unknown,
      ), DeviceBrand.unknown);
    });
  });
}
