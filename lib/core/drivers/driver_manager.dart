import '../base/base_device_driver.dart';
import '../models/device_model.dart';
import '../utils/logger.dart';

/// Central registry and command router for all device drivers.
///
/// Usage:
/// ```dart
/// final manager = DriverManager();
/// manager.registerDriver(KasaDriver());
/// manager.registerDriver(CyncDriver());
///
/// // Bind a specific device to its driver:
/// await manager.bindDevice(device);
///
/// // Send a command:
/// await manager.toggle(device.deviceId, true);
/// ```
class DriverManager {
  DriverManager() : _driverPrototypes = {}, _boundDrivers = {};

  /// Map of driverId → prototype instance (used to create new bindings).
  final Map<String, BaseDeviceDriver> _driverPrototypes;

  /// Map of deviceId → initialised driver instance.
  final Map<String, BaseDeviceDriver> _boundDrivers;

  // -----------------------------------------------------------------------
  // Registration
  // -----------------------------------------------------------------------

  /// Register a driver prototype.  Must be called before [bindDevice].
  void registerDriver(BaseDeviceDriver driver) {
    _driverPrototypes[driver.driverId] = driver;
    AppLogger.info('DriverManager: registered driver "${driver.driverId}"');
  }

  /// Returns all registered driver prototypes (useful for the Developer Mode
  /// driver picker UI).
  List<BaseDeviceDriver> get registeredDrivers =>
      List.unmodifiable(_driverPrototypes.values);

  // -----------------------------------------------------------------------
  // Binding devices to drivers
  // -----------------------------------------------------------------------

  /// Initialise a driver instance for [device] and bind it by device ID.
  ///
  /// The brand of the device determines which registered driver prototype is
  /// used.  The driver is initialised with the device's [DeviceModel.extraConfig].
  Future<void> bindDevice(DeviceModel device) async {
    final driverId = _driverIdForBrand(device.brand);
    final prototype = _driverPrototypes[driverId];

    if (prototype == null) {
      throw DriverInitException(
        'No driver registered for brand "${device.brand.name}" '
        '(expected driverId="$driverId").',
      );
    }

    // Each device gets its own dedicated driver instance.
    final existing = _boundDrivers.remove(device.deviceId);
    if (existing != null) {
      await existing.dispose();
    }

    final instance = _cloneDriver(prototype);
    await instance.initialize(device, device.extraConfig);
    _boundDrivers[device.deviceId] = instance;
    AppLogger.info(
      'DriverManager: bound device "${device.deviceId}" '
      'to driver "${driverId}"',
    );
  }

  /// Release the driver bound to [deviceId] and remove it from the registry.
  Future<void> unbindDevice(String deviceId) async {
    final driver = _boundDrivers.remove(deviceId);
    if (driver != null) {
      await driver.dispose();
      AppLogger.info('DriverManager: unbound device "$deviceId"');
    }
  }

  /// Release all bound drivers (called on app dispose / sign-out).
  Future<void> disposeAll() async {
    final ids = List<String>.from(_boundDrivers.keys);
    for (final id in ids) {
      await unbindDevice(id);
    }
  }

  // -----------------------------------------------------------------------
  // Command routing
  // -----------------------------------------------------------------------

  Future<void> toggle(String deviceId, bool value) =>
      _driver(deviceId).toggle(value);

  Future<void> setBrightness(String deviceId, double brightness) =>
      _driver(deviceId).setBrightness(brightness);

  Future<void> setColorTemperature(String deviceId, int kelvin) =>
      _driver(deviceId).setColorTemperature(kelvin);

  Future<void> setColor(String deviceId, int r, int g, int b) =>
      _driver(deviceId).setColor(r, g, b);

  Future<bool> getPowerStatus(String deviceId) =>
      _driver(deviceId).getPowerStatus();

  Future<double?> getBrightness(String deviceId) =>
      _driver(deviceId).getBrightness();

  Future<Map<String, dynamic>> getDeviceInfo(String deviceId) =>
      _driver(deviceId).getDeviceInfo();

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  BaseDeviceDriver _driver(String deviceId) {
    final driver = _boundDrivers[deviceId];
    if (driver == null) {
      throw StateError(
        'No driver bound for device "$deviceId". '
        'Call bindDevice() first.',
      );
    }
    return driver;
  }

  bool isBound(String deviceId) => _boundDrivers.containsKey(deviceId);

  /// Maps a [DeviceBrand] to the canonical driver ID string used during
  /// registration.
  static String _driverIdForBrand(DeviceBrand brand) {
    switch (brand) {
      case DeviceBrand.kasa:
        return 'kasa';
      case DeviceBrand.cync:
        return 'cync';
      case DeviceBrand.leviton:
        return 'leviton';
      case DeviceBrand.matter:
        return 'matter';
      case DeviceBrand.unknown:
        return 'unknown';
    }
  }

  /// Creates a fresh driver instance by calling [BaseDeviceDriver.clone] on
  /// the registered prototype.  This guarantees each device binding gets its
  /// own isolated mutable state (sockets, auth tokens, etc.).
  BaseDeviceDriver _cloneDriver(BaseDeviceDriver prototype) {
    return prototype.clone();
  }
}
