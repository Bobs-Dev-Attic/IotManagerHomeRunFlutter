import '../models/device_model.dart';
import '../models/driver_config.dart';

/// Abstract base class that every device driver must implement.
///
/// The Driver Framework routes all UI commands through [DriverManager],
/// which resolves the correct [BaseDeviceDriver] instance for a given device
/// and delegates the call here.
abstract class BaseDeviceDriver {
  /// Unique brand/protocol identifier, e.g. "kasa", "cync", "leviton".
  String get driverId;

  /// Human-readable name shown in the Developer Mode driver list.
  String get displayName;

  /// Schema for the JSON-based configuration UI.  Each [DriverConfigField]
  /// describes one input field that the user must fill in before the driver
  /// can be used (e.g. API tokens, mesh keys, IP ranges).
  List<DriverConfigField> get configSchema;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Called once after the driver is registered with [DriverManager].
  ///
  /// Use this to open sockets, establish OAuth sessions, seed local caches,
  /// etc.  Throws [DriverInitException] on unrecoverable errors.
  Future<void> initialize(DeviceModel device, Map<String, dynamic> config);

  /// Release any resources held by this driver (sockets, HTTP clients …).
  Future<void> dispose();

  // -----------------------------------------------------------------------
  // Commands
  // -----------------------------------------------------------------------

  /// Turn the device on ([value] = true) or off ([value] = false).
  Future<void> toggle(bool value);

  /// Set brightness in the range [0.0, 1.0].
  ///
  /// Drivers that do not support dimming should throw [UnsupportedError].
  Future<void> setBrightness(double brightness);

  /// Set the colour temperature in Kelvin (e.g. 2700 – 6500 K).
  ///
  /// Drivers that do not support colour temperature should throw
  /// [UnsupportedError].
  Future<void> setColorTemperature(int kelvin);

  /// Set an RGB colour where each component is in [0, 255].
  ///
  /// Drivers that do not support RGB should throw [UnsupportedError].
  Future<void> setColor(int r, int g, int b);

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  /// Returns the current power state.  `true` = on, `false` = off.
  Future<bool> getPowerStatus();

  /// Returns the current brightness in [0.0, 1.0], or `null` if the device
  /// does not support dimming.
  Future<double?> getBrightness();

  /// Returns a map of raw device info (firmware version, signal strength, …).
  /// The keys are driver-specific.
  Future<Map<String, dynamic>> getDeviceInfo();
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a driver cannot be initialised.
class DriverInitException implements Exception {
  const DriverInitException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DriverInitException: $message${cause != null ? ' (cause: $cause)' : ''}';
}

/// Thrown when a command fails at the driver level.
class DriverCommandException implements Exception {
  const DriverCommandException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DriverCommandException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}
