import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/base/base_device_driver.dart';
import '../../core/base/device_capability.dart';
import '../../core/models/device_model.dart';
import '../../core/models/driver_config.dart';
import '../../core/utils/logger.dart';

/// Matter protocol bridge driver.
///
/// Routes all commands through a native platform channel so the host app
/// can integrate with the `esp_matter` SDK (Android/iOS) or the OS-level
/// Matter SDK available on iOS 16+ and Android 8.1+.
///
/// The native side (Kotlin/Swift) must register a [MethodChannel] handler
/// with the name [_channelName] and respond to the methods listed below.
class MatterDriver extends BaseDeviceDriver {
  static const String _channelName = 'com.iotmanager/matter';

  late MethodChannel _channel;
  late DeviceModel _device;
  String? _nodeId;

  MatterDriver({MethodChannel? channel}) {
    _channel = channel ?? const MethodChannel(_channelName);
  }

  @override
  String get driverId => 'matter';

  @override
  MatterDriver clone() => MatterDriver();

  @override
  String get displayName => 'Matter (Platform Channel)';

  @override
  String get manufacturer => 'Connectivity Standards Alliance';

  @override
  Set<DeviceCapability> get capabilities => const {
        DeviceCapability.power,
        DeviceCapability.brightness,
        DeviceCapability.colorTemperature,
        DeviceCapability.color,
        DeviceCapability.eventStreaming,
      };

  @override
  List<DriverConfigField> get configSchema => [
        const DriverConfigField(
          key: 'nodeId',
          label: 'Matter Node ID',
          type: DriverConfigFieldType.text,
          hint: 'Numeric node ID assigned during commissioning',
        ),
        const DriverConfigField(
          key: 'endpointId',
          label: 'Endpoint ID',
          type: DriverConfigFieldType.integer,
          defaultValue: '1',
          required: false,
        ),
      ];

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  @override
  Future<void> initialize(
    DeviceModel device,
    Map<String, dynamic> config,
  ) async {
    _device = device;
    _nodeId = config['nodeId'] as String? ??
        device.extraConfig['nodeId'] as String?;
    if (_nodeId == null) {
      throw DriverInitException(
        'MatterDriver requires "nodeId" in config for device '
        '"${device.deviceId}".',
      );
    }

    // Tell the native side to initialise the Matter session for this node.
    try {
      await _channel.invokeMethod<void>('initialize', {
        'nodeId': _nodeId,
        'endpointId': config['endpointId'] ?? 1,
      });
    } on PlatformException catch (e) {
      throw DriverInitException(
        'MatterDriver: native initialization failed',
        cause: e,
      );
    }

    AppLogger.info('MatterDriver: initialized nodeId=$_nodeId');
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<void>('dispose', {'nodeId': _nodeId});
    } catch (_) {}
    AppLogger.info('MatterDriver: disposed for ${_device.deviceId}');
  }

  // -----------------------------------------------------------------------
  // Commands
  // -----------------------------------------------------------------------

  @override
  Future<void> toggle(bool value) async {
    await _invoke('toggle', {'nodeId': _nodeId, 'on': value});
  }

  @override
  Future<void> setBrightness(double brightness) async {
    final level = (brightness.clamp(0.0, 1.0) * 254).round();
    await _invoke('setBrightness', {'nodeId': _nodeId, 'level': level});
  }

  @override
  Future<void> setColorTemperature(int kelvin) async {
    // Matter uses mireds: mireds = 1,000,000 / kelvin
    final mireds = (1000000 / kelvin).round().clamp(0, 65279);
    await _invoke(
        'setColorTemperature', {'nodeId': _nodeId, 'mireds': mireds});
  }

  @override
  Future<void> setColor(int r, int g, int b) async {
    await _invoke('setColor', {'nodeId': _nodeId, 'r': r, 'g': g, 'b': b});
  }

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  @override
  Future<bool> getPowerStatus() async {
    final result = await _invoke('getPowerStatus', {'nodeId': _nodeId});
    return result?['on'] as bool? ?? false;
  }

  @override
  Future<double?> getBrightness() async {
    final result = await _invoke('getBrightness', {'nodeId': _nodeId});
    final level = result?['level'] as int?;
    return level != null ? level / 254.0 : null;
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    return await _invoke('getDeviceInfo', {'nodeId': _nodeId}) ?? {};
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>?> _invoke(
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        method,
        args,
      );
      return result?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      throw DriverCommandException(
        'MatterDriver: platform channel error in "$method"',
        cause: e,
      );
    }
  }
}
