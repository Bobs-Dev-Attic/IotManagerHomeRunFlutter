import 'package:cloud_firestore/cloud_firestore.dart';

/// Describes the brand / protocol type of a device.
enum DeviceBrand {
  kasa,
  cync,
  leviton,
  matter,
  unknown,
}

/// Describes the generic capability category.
enum DeviceType {
  smartPlug,
  dimmerSwitch,
  colorBulb,
  sensor,
  unknown,
}

/// Immutable value object that represents a user's registered IoT device.
///
/// Stored verbatim in Firestore under `users/{uid}/devices/{deviceId}`.
class DeviceModel {
  const DeviceModel({
    required this.deviceId,
    required this.userId,
    required this.displayName,
    required this.brand,
    required this.type,
    this.ipAddress,
    this.macAddress,
    this.model,
    this.firmwareVersion,
    this.extraConfig = const {},
    this.isOnline = false,
    this.isPoweredOn = false,
    this.brightness,
    this.createdAt,
    this.updatedAt,
  });

  final String deviceId;
  final String userId;
  final String displayName;
  final DeviceBrand brand;
  final DeviceType type;

  /// Local IP address — relevant for Kasa / Matter devices.
  final String? ipAddress;

  /// MAC address — used as a stable device identity across IP changes.
  final String? macAddress;

  final String? model;
  final String? firmwareVersion;

  /// Brand-specific configuration (Cync mesh keys, API tokens, etc.).
  final Map<String, dynamic> extraConfig;

  // ---- Cached live state (kept in sync by DriverManager) ----

  final bool isOnline;
  final bool isPoweredOn;

  /// Current brightness in [0.0, 1.0], or null when unsupported.
  final double? brightness;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // -----------------------------------------------------------------------
  // Serialisation
  // -----------------------------------------------------------------------

  factory DeviceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DeviceModel(
      deviceId: doc.id,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Unknown Device',
      brand: _brandFromString(data['brand'] as String?),
      type: _typeFromString(data['type'] as String?),
      ipAddress: data['ipAddress'] as String?,
      macAddress: data['macAddress'] as String?,
      model: data['model'] as String?,
      firmwareVersion: data['firmwareVersion'] as String?,
      extraConfig:
          (data['extraConfig'] as Map<String, dynamic>?) ?? const {},
      isOnline: data['isOnline'] as bool? ?? false,
      isPoweredOn: data['isPoweredOn'] as bool? ?? false,
      brightness: (data['brightness'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'brand': brand.name,
      'type': type.name,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (macAddress != null) 'macAddress': macAddress,
      if (model != null) 'model': model,
      if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
      'extraConfig': extraConfig,
      'isOnline': isOnline,
      'isPoweredOn': isPoweredOn,
      if (brightness != null) 'brightness': brightness,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // -----------------------------------------------------------------------
  // copyWith
  // -----------------------------------------------------------------------

  DeviceModel copyWith({
    String? deviceId,
    String? userId,
    String? displayName,
    DeviceBrand? brand,
    DeviceType? type,
    String? ipAddress,
    String? macAddress,
    String? model,
    String? firmwareVersion,
    Map<String, dynamic>? extraConfig,
    bool? isOnline,
    bool? isPoweredOn,
    double? brightness,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      model: model ?? this.model,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      extraConfig: extraConfig ?? this.extraConfig,
      isOnline: isOnline ?? this.isOnline,
      isPoweredOn: isPoweredOn ?? this.isPoweredOn,
      brightness: brightness ?? this.brightness,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceModel && other.deviceId == deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  static DeviceBrand _brandFromString(String? value) {
    return DeviceBrand.values.firstWhere(
      (b) => b.name == value,
      orElse: () => DeviceBrand.unknown,
    );
  }

  static DeviceType _typeFromString(String? value) {
    return DeviceType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => DeviceType.unknown,
    );
  }

  @override
  String toString() =>
      'DeviceModel(id: $deviceId, name: $displayName, brand: ${brand.name})';
}
