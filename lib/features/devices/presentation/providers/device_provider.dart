import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drivers/driver_manager.dart';
import '../../../../core/models/device_model.dart';
import '../../../../core/services/firebase_device_registry_service.dart';
import '../../../../drivers/cync/cync_driver.dart';
import '../../../../drivers/kasa/kasa_driver.dart';
import '../../../../drivers/leviton/leviton_driver.dart';
import '../../../../drivers/matter/matter_driver.dart';

// ---------------------------------------------------------------------------
// Service providers
// ---------------------------------------------------------------------------

/// Provides the [FirebaseDeviceRegistryService] singleton.
final deviceRegistryServiceProvider =
    Provider<FirebaseDeviceRegistryService>(
  (ref) => FirebaseDeviceRegistryService(),
);

/// Provides the [DriverManager] singleton with all drivers registered.
final driverManagerProvider = Provider<DriverManager>((ref) {
  final manager = DriverManager();
  manager.registerDriver(KasaDriver());
  manager.registerDriver(CyncDriver());
  manager.registerDriver(LevitonDriver());
  manager.registerDriver(MatterDriver());
  return manager;
});

// ---------------------------------------------------------------------------
// Device list stream
// ---------------------------------------------------------------------------

/// Real-time stream of the user's registered devices from Firestore.
final devicesStreamProvider = StreamProvider<List<DeviceModel>>((ref) {
  final service = ref.watch(deviceRegistryServiceProvider);
  return service.devicesStream;
});

// ---------------------------------------------------------------------------
// Per-device power state notifier
// ---------------------------------------------------------------------------

/// A [StateNotifier] that tracks and updates the live state for one device.
class DeviceStateNotifier extends StateNotifier<DeviceModel> {
  DeviceStateNotifier({
    required DeviceModel device,
    required DriverManager manager,
    required FirebaseDeviceRegistryService registryService,
  })  : _manager = manager,
        _registryService = registryService,
        super(device);

  final DriverManager _manager;
  final FirebaseDeviceRegistryService _registryService;
  Timer? _brightnessDebounce;

  Future<void> toggle() async {
    final newValue = !state.isPoweredOn;
    try {
      await _manager.toggle(state.deviceId, newValue);
      state = state.copyWith(isPoweredOn: newValue);
      await _registryService.syncLiveState(
        deviceId: state.deviceId,
        isOnline: state.isOnline,
        isPoweredOn: newValue,
      );
    } catch (e) {
      // Revert optimistic update on failure.
      state = state.copyWith(isPoweredOn: !newValue);
      rethrow;
    }
  }

  Future<void> setBrightness(double brightness) async {
    state = state.copyWith(brightness: brightness);
    _brightnessDebounce?.cancel();
    _brightnessDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        await _manager.setBrightness(state.deviceId, brightness);
        await _registryService.syncLiveState(
          deviceId: state.deviceId,
          isOnline: state.isOnline,
          isPoweredOn: state.isPoweredOn,
          brightness: brightness,
        );
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _brightnessDebounce?.cancel();
    super.dispose();
  }

  Future<void> refreshStatus() async {
    try {
      final powered = await _manager.getPowerStatus(state.deviceId);
      final brightness = await _manager.getBrightness(state.deviceId);
      state = state.copyWith(
        isPoweredOn: powered,
        brightness: brightness,
        isOnline: true,
      );
    } catch (_) {
      state = state.copyWith(isOnline: false);
    }
  }
}

/// Family provider — one notifier per device ID.
final deviceStateProvider = StateNotifierProvider.family<DeviceStateNotifier,
    DeviceModel, DeviceModel>(
  (ref, device) => DeviceStateNotifier(
    device: device,
    manager: ref.watch(driverManagerProvider),
    registryService: ref.watch(deviceRegistryServiceProvider),
  ),
);
