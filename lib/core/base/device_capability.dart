/// Capability tags advertised by a driver so the UI and command router can
/// decide which controls to render and which calls are safe to make.
///
/// A capability is a *promise* by the driver that the corresponding command
/// (or event subscription) will succeed for the bound device. Drivers should
/// never claim a capability they cannot fulfil; UI code uses
/// [BaseDeviceDriver.supports] to skip unsupported widgets instead of
/// catching `UnsupportedError` at runtime.
enum DeviceCapability {
  power,
  brightness,
  colorTemperature,
  color,
  energyMetering,
  motionSensing,
  temperatureSensing,
  humiditySensing,
  contactSensing,
  lock,
  thermostat,
  battery,
  firmwareUpdate,
  scenes,
  eventStreaming,
}

/// Base class for unsolicited driver-emitted state changes.
///
/// Drivers that maintain a persistent connection (e.g. Matter subscriptions,
/// MQTT, websockets) should publish [DeviceStateEvent]s instead of forcing
/// the UI to poll. Drivers without push support simply expose
/// `Stream<DeviceStateEvent>.empty()`.
abstract class DeviceStateEvent {
  const DeviceStateEvent({required this.deviceId, required this.timestamp});

  final String deviceId;
  final DateTime timestamp;
}

class PowerStateEvent extends DeviceStateEvent {
  const PowerStateEvent({
    required super.deviceId,
    required super.timestamp,
    required this.isPoweredOn,
  });

  final bool isPoweredOn;
}

class BrightnessEvent extends DeviceStateEvent {
  const BrightnessEvent({
    required super.deviceId,
    required super.timestamp,
    required this.brightness,
  });

  /// 0.0 – 1.0
  final double brightness;
}

class ConnectivityEvent extends DeviceStateEvent {
  const ConnectivityEvent({
    required super.deviceId,
    required super.timestamp,
    required this.isOnline,
  });

  final bool isOnline;
}

class SensorReadingEvent extends DeviceStateEvent {
  const SensorReadingEvent({
    required super.deviceId,
    required super.timestamp,
    required this.kind,
    required this.value,
    this.unit,
  });

  final String kind; // e.g. 'temperature', 'humidity', 'motion'
  final num value;
  final String? unit;
}

/// Lightweight discovery hint emitted by [BaseDeviceDriver.discover].
///
/// Drivers that own a discovery transport (mDNS, BLE, vendor cloud listing)
/// can return hints that the UI surfaces in the Add Device flow. Hints are
/// **not** registered devices — the user still confirms and provides any
/// remaining configuration before binding.
class DiscoveryHint {
  const DiscoveryHint({
    required this.driverId,
    required this.label,
    this.ipAddress,
    this.metadata = const {},
  });

  final String driverId;
  final String label;
  final String? ipAddress;
  final Map<String, String> metadata;
}
