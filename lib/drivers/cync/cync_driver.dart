import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/base/base_device_driver.dart';
import '../../core/models/device_model.dart';
import '../../core/models/driver_config.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/resilience.dart';

/// GE Cync Cloud-Bridge driver.
///
/// Authenticates via Cync's private OAuth2-style API, then issues REST
/// commands to the Cync cloud to control mesh lighting devices.
///
/// The "mesh keys" and device IDs are stored in [DeviceModel.extraConfig]
/// under the keys defined in [configSchema].
class CyncDriver extends BaseDeviceDriver {
  static const String _baseUrl = 'https://api.gelighting.com/v2';
  static const String _authEndpoint = '/user_auth';
  static const String _deviceEndpoint = '/user/devices';

  late Dio _dio;
  late DeviceModel _device;
  String? _accessToken;
  String? _userId;
  String? _deviceId;
  final CircuitBreaker _circuitBreaker = CircuitBreaker();

  CyncDriver({Dio? dio}) {
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
  String get driverId => 'cync';

  @override
  CyncDriver clone() => CyncDriver();

  @override
  String get displayName => 'GE Cync (Cloud Bridge)';

  @override
  List<DriverConfigField> get configSchema => [
        const DriverConfigField(
          key: 'email',
          label: 'Cync Account Email',
          type: DriverConfigFieldType.text,
          hint: 'user@example.com',
        ),
        const DriverConfigField(
          key: 'password',
          label: 'Cync Account Password',
          type: DriverConfigFieldType.password,
        ),
        const DriverConfigField(
          key: 'cyncDeviceId',
          label: 'Cync Device ID',
          type: DriverConfigFieldType.text,
          hint: 'Numeric device ID from Cync app',
        ),
        const DriverConfigField(
          key: 'meshKey',
          label: 'Mesh Key (optional)',
          type: DriverConfigFieldType.text,
          required: false,
          hint: 'Used for local mesh commands',
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
    _deviceId = config['cyncDeviceId'] as String?;

    final email = config['email'] as String?;
    final password = config['password'] as String?;

    if (email == null || password == null) {
      throw DriverInitException(
        'CyncDriver requires "email" and "password" in config.',
      );
    }

    await _authenticate(email, password);
    AppLogger.info('CyncDriver: initialized for device ${device.deviceId}');
  }

  @override
  Future<void> dispose() async {
    _accessToken = null;
    _dio.close();
    AppLogger.info('CyncDriver: disposed for ${_device.deviceId}');
  }

  // -----------------------------------------------------------------------
  // Commands
  // -----------------------------------------------------------------------

  @override
  Future<void> toggle(bool value) async {
    await _ensureAuthenticated();
    await _deviceRequest(
      method: 'PUT',
      path: '/devices/$_deviceId/properties',
      body: {'power': value ? 1 : 0},
    );
    AppLogger.info('CyncDriver: toggle(${value ? "on" : "off"})');
  }

  @override
  Future<void> setBrightness(double brightness) async {
    await _ensureAuthenticated();
    final percent = (brightness.clamp(0.0, 1.0) * 100).round();
    await _deviceRequest(
      method: 'PUT',
      path: '/devices/$_deviceId/properties',
      body: {'brightness': percent},
    );
    AppLogger.info('CyncDriver: setBrightness($percent%)');
  }

  @override
  Future<void> setColorTemperature(int kelvin) async {
    await _ensureAuthenticated();
    await _deviceRequest(
      method: 'PUT',
      path: '/devices/$_deviceId/properties',
      body: {'colorTemperature': kelvin},
    );
  }

  @override
  Future<void> setColor(int r, int g, int b) async {
    await _ensureAuthenticated();
    await _deviceRequest(
      method: 'PUT',
      path: '/devices/$_deviceId/properties',
      body: {'color': {'r': r, 'g': g, 'b': b}},
    );
  }

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  @override
  Future<bool> getPowerStatus() async {
    await _ensureAuthenticated();
    final response = await _deviceRequest(
      method: 'GET',
      path: '/devices/$_deviceId/properties',
    );
    return (response?['power'] as int? ?? 0) == 1;
  }

  @override
  Future<double?> getBrightness() async {
    await _ensureAuthenticated();
    final response = await _deviceRequest(
      method: 'GET',
      path: '/devices/$_deviceId/properties',
    );
    final raw = response?['brightness'] as int?;
    return raw != null ? raw / 100.0 : null;
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    await _ensureAuthenticated();
    final response = await _deviceRequest(
      method: 'GET',
      path: '/devices/$_deviceId',
    );
    return response ?? {};
  }

  // -----------------------------------------------------------------------
  // OAuth2 / Authentication
  // -----------------------------------------------------------------------

  Future<void> _authenticate(String email, String password) async {
    try {
      final response = await _circuitBreaker.run(() => retryWithBackoff(
            task: () => _dio.post<Map<String, dynamic>>(
              _authEndpoint,
              data: jsonEncode({'email': email, 'password': password}),
            ),
          ));
      final data = response.data;
      _accessToken = data?['access_token'] as String?;
      _userId = data?['user_id'] as String?;

      if (_accessToken == null) {
        throw DriverInitException(
          'CyncDriver: authentication failed — no access_token in response.',
        );
      }

      _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
      AppLogger.info('CyncDriver: authenticated as userId=$_userId');
    } on DioException catch (e) {
      throw DriverInitException(
        'CyncDriver: authentication request failed',
        cause: e,
      );
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (_accessToken == null) {
      throw DriverCommandException(
        'CyncDriver: not authenticated — call initialize() first.',
      );
    }
  }

  Future<Map<String, dynamic>?> _deviceRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    try {
      late Response<dynamic> response;
      if (method == 'GET') {
        response = await _circuitBreaker.run(() => retryWithBackoff(task: () => _dio.get<dynamic>(path)));
      } else {
        response = await _circuitBreaker.run(() => retryWithBackoff(task: () => _dio.put<dynamic>(path, data: body)));
      }
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _accessToken = null;
        throw DriverCommandException('Session expired. Please re-authenticate.');
      }
      throw DriverCommandException(
        'CyncDriver: API request failed for $path',
        cause: e,
      );
    }
  }
}
