import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/base/base_device_driver.dart';
import '../../core/models/device_model.dart';
import '../../core/models/driver_config.dart';
import '../../core/utils/logger.dart';

/// Leviton Cloud-Bridge driver.
///
/// Authenticates against the Leviton Decora Smart Cloud API (OAuth2 /
/// Resource Owner Password Credentials flow) and controls switches and
/// dimmers via REST endpoints.
class LevitonDriver extends BaseDeviceDriver {
  static const String _baseUrl = 'https://my.leviton.com/api';
  static const String _loginEndpoint = '/Person/login';

  late Dio _dio;
  late DeviceModel _device;

  String? _accessToken;
  String? _residenceId;
  String? _activityId;

  LevitonDriver({Dio? dio}) {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
  }

  @override
  String get driverId => 'leviton';

  @override
  String get displayName => 'Leviton Decora Smart (Cloud Bridge)';

  @override
  List<DriverConfigField> get configSchema => [
        const DriverConfigField(
          key: 'email',
          label: 'Leviton Account Email',
          type: DriverConfigFieldType.text,
          hint: 'user@example.com',
        ),
        const DriverConfigField(
          key: 'password',
          label: 'Leviton Account Password',
          type: DriverConfigFieldType.password,
        ),
        const DriverConfigField(
          key: 'activityId',
          label: 'Activity / Switch ID',
          type: DriverConfigFieldType.text,
          hint: 'Activity ID from the Leviton app',
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
    _activityId = config['activityId'] as String? ??
        (device.extraConfig['activityId'] as String?);

    final email = config['email'] as String?;
    final password = config['password'] as String?;
    if (email == null || password == null) {
      throw DriverInitException(
        'LevitonDriver requires "email" and "password" in config.',
      );
    }

    await _authenticate(email, password);
    AppLogger.info('LevitonDriver: initialized for device ${device.deviceId}');
  }

  @override
  Future<void> dispose() async {
    _accessToken = null;
    _dio.close();
    AppLogger.info('LevitonDriver: disposed for ${_device.deviceId}');
  }

  // -----------------------------------------------------------------------
  // Commands
  // -----------------------------------------------------------------------

  @override
  Future<void> toggle(bool value) async {
    _assertAuth();
    await _activityRequest(
      method: 'PUT',
      body: {'power': value ? 'ON' : 'OFF'},
    );
    AppLogger.info('LevitonDriver: toggle(${value ? "on" : "off"})');
  }

  @override
  Future<void> setBrightness(double brightness) async {
    _assertAuth();
    final percent = (brightness.clamp(0.0, 1.0) * 100).round();
    await _activityRequest(
      method: 'PUT',
      body: {'brightness': percent},
    );
    AppLogger.info('LevitonDriver: setBrightness($percent%)');
  }

  @override
  Future<void> setColorTemperature(int kelvin) =>
      throw UnsupportedError(
          'LevitonDriver does not support colour temperature.');

  @override
  Future<void> setColor(int r, int g, int b) =>
      throw UnsupportedError('LevitonDriver does not support RGB colour.');

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  @override
  Future<bool> getPowerStatus() async {
    _assertAuth();
    final data = await _activityRequest(method: 'GET');
    return (data?['power'] as String?) == 'ON';
  }

  @override
  Future<double?> getBrightness() async {
    _assertAuth();
    final data = await _activityRequest(method: 'GET');
    final raw = data?['brightness'] as int?;
    return raw != null ? raw / 100.0 : null;
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    _assertAuth();
    return await _activityRequest(method: 'GET') ?? {};
  }

  // -----------------------------------------------------------------------
  // OAuth2 Authentication
  // -----------------------------------------------------------------------

  Future<void> _authenticate(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _loginEndpoint,
        data: jsonEncode({'email': email, 'password': password}),
      );
      final data = response.data;
      _accessToken = data?['id'] as String?;

      if (_accessToken == null) {
        throw DriverInitException(
          'LevitonDriver: authentication failed — no token in response.',
        );
      }

      _dio.options.headers['Authorization'] = _accessToken;
      AppLogger.info('LevitonDriver: authenticated successfully');
    } on DioException catch (e) {
      throw DriverInitException(
        'LevitonDriver: authentication request failed',
        cause: e,
      );
    }
  }

  Future<Map<String, dynamic>?> _activityRequest({
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final path = '/Activity/$_activityId';
    try {
      late Response<dynamic> response;
      if (method == 'GET') {
        response = await _dio.get<dynamic>(path);
      } else {
        response = await _dio.put<dynamic>(path, data: body);
      }
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw DriverCommandException(
        'LevitonDriver: API request failed for $path',
        cause: e,
      );
    }
  }

  void _assertAuth() {
    if (_accessToken == null) {
      throw DriverCommandException(
        'LevitonDriver: not authenticated — call initialize() first.',
      );
    }
  }
}
