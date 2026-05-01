import '../../../core/models/device_model.dart';
import '../../../core/services/firebase_device_registry_service.dart';

/// Repository abstraction over [FirebaseDeviceRegistryService].
///
/// Adds caching / batching logic as needed; currently a thin wrapper.
class DeviceRepository {
  DeviceRepository({FirebaseDeviceRegistryService? service})
      : _service = service ?? FirebaseDeviceRegistryService();

  final FirebaseDeviceRegistryService _service;

  Stream<List<DeviceModel>> watchDevices() => _service.devicesStream;

  Future<String> addDevice(DeviceModel device) => _service.addDevice(device);

  Future<void> updateDevice(DeviceModel device) =>
      _service.updateDevice(device);

  Future<void> deleteDevice(String deviceId) =>
      _service.deleteDevice(deviceId);

  Future<DeviceModel?> getDevice(String deviceId) =>
      _service.getDevice(deviceId);
}
