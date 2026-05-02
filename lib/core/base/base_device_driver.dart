import '../models/device_model.dart';
import '../models/driver_config.dart';
import 'device_capability.dart';

/// Abstract base class that every device driver must implement.
///
/// The Driver Framework routes all UI commands through [DriverManager],
/// which resolves the correct [BaseDeviceDriver] instance for a given device
/// and delegates the call here.
///
/// New drivers only need to implement the abstract members. The remaining
/// hooks ([capabilities], [events], [healthCheck], [sensitiveConfigKeys],
/// [discover], [version], [manufacturer]) have safe defaults so older drivers
/// keep working unchanged while new drivers can opt into richer behaviour.
abstract class BaseDeviceDriver {
  /// Unique brand/protocol identifier, e.g. "kasa", "cync", "leviton".
  /// This string is also the lookup key in [DriverManager], so it must be
  /// stable across releases.
  String get driverId;

  /// Human-readable name shown in the Developer Mode driver list.
  String get displayName;

  /// Schema for the JSON-based configuration UI.  Each [DriverConfigField]
  /// describes one input field that the user must fill in before the driver
  /// can be used (e.g. API tokens, mesh keys, IP ranges).
  List<DriverConfigField> get configSchema;

  // -----------------------------------------------------------------------
  // Driver metadata (optional, but recommended)
  // -----------------------------------------------------------------------

  /// Semantic version of the driver implementation. Used by future migration
  /// logic and surfaced in Developer Mode for support diagnostics.
  String get version => '1.0.0';

  /// Display-only manufacturer / vendor string, e.g. "TP-Link", "GE".
  String get manufacturer => '';

  /// Capabilities advertised by this driver. The UI uses [supports] to decide
  /// which controls to render (brightness slider, color picker, etc.) so
  /// drivers should only include capabilities they can actually fulfil.
  ///
  /// Defaults to `{DeviceCapability.power}` for backward compatibility with
  /// the original four drivers.
  Set<DeviceCapability> get capabilities =>
      const {DeviceCapability.power};

  /// `extraConfig` keys that contain secrets and must never be persisted to
  /// remote storage in cleartext. [DriverManager] forwards these to
  /// [DeviceModel.registerSensitiveExtraConfigKeys] on registration so the
  /// serializer redacts them automatically.
  Set<String> get sensitiveConfigKeys => const {};

  /// Returns `true` if this driver supports the given [capability].
  bool supports(DeviceCapability capability) =>
      capabilities.contains(capability);

  /// Stream of unsolicited state-change events. Drivers that hold an open
  /// connection (Matter subscriptions, websockets, MQTT) can publish here so
  /// the UI does not have to poll. Default implementation is an empty stream.
  Stream<DeviceStateEvent> get events => Stream<DeviceStateEvent>.empty();

  /// Lightweight, side-effect-free probe used by background health monitors.
  /// Override to return `false` (or throw) when the device is unreachable.
  Future<bool> healthCheck() async => true;

  /// Optional driver-specific discovery hook. Drivers that own a transport
  /// (mDNS, BLE, vendor cloud listing) can surface candidate devices here so
  /// the Add Device flow can suggest them. Default returns no hints.
  Future<List<DiscoveryHint>> discover({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      const [];

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

  /// Set the color temperature in Kelvin (e.g. 2700 – 6500 K).
  ///
  /// Drivers that do not support color temperature should throw
  /// [UnsupportedError].
  Future<void> setColorTemperature(int kelvin);

  /// Set an RGB color where each component is in [0, 255].
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

  // -----------------------------------------------------------------------
  // Factory
  // -----------------------------------------------------------------------

  /// Create a new, uninitialised instance of this driver.
  ///
  /// [DriverManager] calls this method to obtain a fresh driver instance for
  /// each device binding, ensuring that devices of the same brand never share
  /// mutable driver state (open sockets, auth tokens, …).
  ///
  /// Every concrete driver **must** override this and return `DriverType()`.
  BaseDeviceDriver clone();
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
