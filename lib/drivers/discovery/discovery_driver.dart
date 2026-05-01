import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../../core/models/device_model.dart';
import '../../core/utils/logger.dart';

/// Result returned for each device discovered via mDNS.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.serviceType,
    required this.ipAddress,
    required this.port,
    this.txtRecords = const {},
  });

  final String name;
  final String serviceType;
  final String ipAddress;
  final int port;

  /// mDNS TXT record key-value pairs (used to detect device model/brand).
  final Map<String, String> txtRecords;

  /// Infers the [DeviceBrand] from the mDNS service type or TXT records.
  DeviceBrand get inferredBrand {
    if (serviceType.contains('tplink') || serviceType.contains('kasa')) {
      return DeviceBrand.kasa;
    }
    if (serviceType.contains('matter') || serviceType.contains('_matterc')) {
      return DeviceBrand.matter;
    }
    return DeviceBrand.unknown;
  }

  @override
  String toString() =>
      'DiscoveredDevice(name: $name, ip: $ipAddress:$port, '
      'type: $serviceType)';
}

/// Uses mDNS/Zeroconf (via the `bonsoir` package) to discover Kasa and Matter
/// devices on the local network.
///
/// This handles inter-VLAN discovery on UniFi networks:
/// the app must be connected to the same VLAN/subnet as the devices; the
/// [DiscoveryDriver] simply discovers whatever mDNS traffic is visible.
///
/// Usage:
/// ```dart
/// final driver = DiscoveryDriver();
/// driver.discoveredDevices.listen((device) {
///   print('Found: ${device.name} @ ${device.ipAddress}');
/// });
/// await driver.startDiscovery();
/// // ...later...
/// await driver.stopDiscovery();
/// ```
class DiscoveryDriver {
  static const List<String> _serviceTypes = [
    '_tplink._tcp',   // TP-Link Kasa
    '_matterc._tcp',  // Matter commissioning
    '_matter._tcp',   // Matter operational
    '_hap._tcp',      // HomeKit (Cync/Leviton may advertise this)
    '_http._tcp',     // Generic HTTP-based devices
  ];

  final _discoveredController =
      StreamController<DiscoveredDevice>.broadcast();

  final Map<String, BonsoirDiscovery> _discoveries = {};
  bool _running = false;

  /// Stream of newly discovered devices. Subscribe before calling
  /// [startDiscovery].
  Stream<DiscoveredDevice> get discoveredDevices =>
      _discoveredController.stream;

  // -----------------------------------------------------------------------
  // Control
  // -----------------------------------------------------------------------

  /// Starts mDNS browsing for all [_serviceTypes] in parallel.
  Future<void> startDiscovery() async {
    if (_running) return;
    _running = true;

    for (final serviceType in _serviceTypes) {
      try {
        final discovery = BonsoirDiscovery(type: serviceType);
        await discovery.ready;
        discovery.eventStream?.listen(_handleEvent);
        await discovery.start();
        _discoveries[serviceType] = discovery;
        AppLogger.info('DiscoveryDriver: browsing for $serviceType');
      } catch (e) {
        AppLogger.warning(
          'DiscoveryDriver: failed to start discovery for $serviceType',
          error: e,
        );
      }
    }
  }

  /// Stops all active mDNS browsing sessions.
  Future<void> stopDiscovery() async {
    _running = false;
    for (final entry in _discoveries.entries) {
      try {
        await entry.value.stop();
        AppLogger.info('DiscoveryDriver: stopped browsing for ${entry.key}');
      } catch (e) {
        AppLogger.warning(
          'DiscoveryDriver: error stopping discovery for ${entry.key}',
          error: e,
        );
      }
    }
    _discoveries.clear();
  }

  /// Dispose the stream controller when the driver is no longer needed.
  Future<void> dispose() async {
    await stopDiscovery();
    await _discoveredController.close();
  }

  // -----------------------------------------------------------------------
  // Event handling
  // -----------------------------------------------------------------------

  void _handleEvent(BonsoirDiscoveryEvent event) {
    if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound) {
      final service = event.service;
      if (service == null) return;

      // Resolve the service to get the IP address.
      if (service is ResolvedBonsoirService) {
        _emitResolved(service);
      }
    } else if (event.type ==
        BonsoirDiscoveryEventType.discoveryServiceResolved) {
      final service = event.service;
      if (service is ResolvedBonsoirService) {
        _emitResolved(service);
      }
    }
  }

  void _emitResolved(ResolvedBonsoirService service) {
    final ip = service.host;
    final port = service.port;
    if (ip == null || ip.isEmpty) return;

    final discovered = DiscoveredDevice(
      name: service.name,
      serviceType: service.type,
      ipAddress: ip,
      port: port,
      txtRecords: service.attributes ?? const {},
    );

    AppLogger.info('DiscoveryDriver: resolved $discovered');
    _discoveredController.add(discovered);
  }
}
