import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/device_model.dart';
import '../utils/logger.dart';

/// Synchronises the device registry between Firestore and the local app state.
///
/// Firestore path: `users/{uid}/devices/{deviceId}`
///
/// The service exposes a real-time stream ([devicesStream]) powered by
/// Firestore snapshots so that Riverpod providers stay up to date
/// automatically.
class FirebaseDeviceRegistryService {
  FirebaseDeviceRegistryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _devicesCollection =>
      _firestore.collection('users').doc(_uid).collection('devices');

  // -----------------------------------------------------------------------
  // Real-time stream
  // -----------------------------------------------------------------------

  /// Emits a new list every time the Firestore collection changes.
  Stream<List<DeviceModel>> get devicesStream {
    return _devicesCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => DeviceModel.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // -----------------------------------------------------------------------
  // CRUD
  // -----------------------------------------------------------------------

  /// Adds a new device to Firestore and returns the assigned document ID.
  Future<String> addDevice(DeviceModel device) async {
    try {
      final docRef = await _devicesCollection.add(
        device.copyWith(userId: _uid).toFirestore(),
      );
      AppLogger.info(
        'FirebaseDeviceRegistryService: added device "${docRef.id}"',
      );
      return docRef.id;
    } on FirebaseException catch (e, st) {
      AppLogger.error('addDevice failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Updates an existing device document.
  Future<void> updateDevice(DeviceModel device) async {
    try {
      await _devicesCollection
          .doc(device.deviceId)
          .update(device.toFirestore());
      AppLogger.info(
        'FirebaseDeviceRegistryService: updated device "${device.deviceId}"',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error('updateDevice failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deletes a device document.
  Future<void> deleteDevice(String deviceId) async {
    try {
      await _devicesCollection.doc(deviceId).delete();
      AppLogger.info(
        'FirebaseDeviceRegistryService: deleted device "$deviceId"',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error('deleteDevice failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Fetches a single device by ID (one-shot, not a stream).
  Future<DeviceModel?> getDevice(String deviceId) async {
    try {
      final doc = await _devicesCollection.doc(deviceId).get();
      if (!doc.exists) return null;
      return DeviceModel.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error('getDevice failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Persists only the live-state fields (online/power/brightness) back to
  /// Firestore so the cloud registry stays current.
  Future<void> syncLiveState({
    required String deviceId,
    required bool isOnline,
    required bool isPoweredOn,
    double? brightness,
  }) async {
    try {
      final updates = <String, dynamic>{
        'isOnline': isOnline,
        'isPoweredOn': isPoweredOn,
        if (brightness != null) 'brightness': brightness,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _devicesCollection.doc(deviceId).update(updates);
    } on FirebaseException catch (e, st) {
      AppLogger.error('syncLiveState failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
