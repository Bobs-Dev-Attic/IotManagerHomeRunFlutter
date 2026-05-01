import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/base/base_device_driver.dart';
import '../../core/models/device_model.dart';
import '../../core/models/driver_config.dart';
import '../../core/utils/logger.dart';

/// TP-Link Kasa driver — local control over TCP using the XOR cipher.
///
/// The Kasa protocol sends JSON payloads encrypted with a simple XOR stream
/// cipher.  The first byte of the cipher stream is the static key (0xAB = 171)
/// and each subsequent key byte is the previous *ciphertext* byte (autokey
/// variant).
///
/// Reference: https://github.com/softScheck/tplink-smartplug
class KasaDriver extends BaseDeviceDriver {
  static const int _defaultPort = 9999;

  /// XOR starting key used in the Kasa protocol cipher.
  static const int xorKey = 171; // 0xAB

  static const Duration _timeout = Duration(seconds: 5);
  static const int _maxPayloadBytes = 64 * 1024;

  // Kasa command JSON payloads
  static const String _cmdGetSysInfo = '{"system":{"get_sysinfo":{}}}';

  static String _cmdSetRelayState(bool on) =>
      '{"system":{"set_relay_state":{"state":${on ? 1 : 0}}}}';

  static String _cmdSetBrightness(int percent) =>
      '{"smartlife.iot.dimmer":{"set_dimmer_transition":'
      '{"brightness":$percent,"duration":1}}}';

  late DeviceModel _device;
  late String _ipAddress;
  late int _port;

  bool _initialized = false;

  @override
  KasaDriver clone() => KasaDriver();

  // -----------------------------------------------------------------------
  // BaseDeviceDriver identity
  // -----------------------------------------------------------------------

  @override
  String get driverId => 'kasa';

  @override
  String get displayName => 'TP-Link Kasa (Local TCP)';

  @override
  List<DriverConfigField> get configSchema => [
        const DriverConfigField(
          key: 'ipAddress',
          label: 'Device IP Address',
          type: DriverConfigFieldType.ipAddress,
          hint: '192.168.1.100',
        ),
        const DriverConfigField(
          key: 'port',
          label: 'Port',
          type: DriverConfigFieldType.integer,
          defaultValue: '9999',
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
    final ip = (config['ipAddress'] as String?) ?? device.ipAddress;
    if (ip == null || ip.isEmpty) {
      throw DriverInitException(
        'KasaDriver requires an IP address for device "${device.deviceId}".',
      );
    }
    _ipAddress = ip;
    _port = (config['port'] as int?) ?? _defaultPort;
    _initialized = true;
    AppLogger.info('KasaDriver: initialized for $_ipAddress:$_port');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    AppLogger.info('KasaDriver: disposed for ${_device.deviceId}');
  }

  // -----------------------------------------------------------------------
  // Commands
  // -----------------------------------------------------------------------

  @override
  Future<void> toggle(bool value) async {
    _assertInit();
    await _sendCommand(_cmdSetRelayState(value));
    AppLogger.info(
        'KasaDriver: toggle(${value ? "on" : "off"}) sent to $_ipAddress');
  }

  @override
  Future<void> setBrightness(double brightness) async {
    _assertInit();
    final percent = (brightness.clamp(0.0, 1.0) * 100).round();
    await _sendCommand(_cmdSetBrightness(percent));
    AppLogger.info('KasaDriver: setBrightness($percent%) sent to $_ipAddress');
  }

  @override
  Future<void> setColorTemperature(int kelvin) =>
      throw UnsupportedError('KasaDriver does not support color temperature.');

  @override
  Future<void> setColor(int r, int g, int b) =>
      throw UnsupportedError('KasaDriver does not support RGB color.');

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  @override
  Future<bool> getPowerStatus() async {
    _assertInit();
    final info = await _sendCommand(_cmdGetSysInfo);
    final sysinfo = _extractNested(info, ['system', 'get_sysinfo']);
    return (sysinfo?['relay_state'] as int? ?? 0) == 1;
  }

  @override
  Future<double?> getBrightness() async {
    _assertInit();
    final info = await _sendCommand(_cmdGetSysInfo);
    final sysinfo = _extractNested(info, ['system', 'get_sysinfo']);
    final raw = sysinfo?['brightness'] as int?;
    return raw != null ? raw / 100.0 : null;
  }

  @override
  Future<Map<String, dynamic>> getDeviceInfo() async {
    _assertInit();
    return await _sendCommand(_cmdGetSysInfo);
  }

  // -----------------------------------------------------------------------
  // XOR cipher  (public static so tests can verify them independently)
  // -----------------------------------------------------------------------

  /// Encrypts [plaintext] using the Kasa XOR autokey cipher.
  ///
  /// Prepends a 4-byte big-endian length header, then XOR-encrypts each byte
  /// using the autokey stream (initial key = [xorKey] = 171 = 0xAB, then each
  /// subsequent key = previous ciphertext byte).
  static Uint8List encrypt(String plaintext) {
    final bytes = const Utf8Encoder().convert(plaintext);
    final length = bytes.length;

    final result = Uint8List(4 + length);
    // Big-endian 4-byte length header
    result[0] = (length >> 24) & 0xFF;
    result[1] = (length >> 16) & 0xFF;
    result[2] = (length >> 8) & 0xFF;
    result[3] = length & 0xFF;

    int key = xorKey;
    for (int i = 0; i < length; i++) {
      final cipher = bytes[i] ^ key;
      result[4 + i] = cipher;
      key = cipher; // autokey: next key = previous ciphertext byte
    }
    return result;
  }

  /// Decrypts a Kasa XOR-encoded payload.
  ///
  /// If [stripHeader] is true (default), the first 4 bytes (length header)
  /// are skipped before decrypting.
  static String decrypt(Uint8List data, {bool stripHeader = true}) {
    final start = (stripHeader && data.length > 4) ? 4 : 0;
    final buffer = <int>[];
    int key = xorKey;
    for (int i = start; i < data.length; i++) {
      final plain = data[i] ^ key;
      key = data[i]; // autokey: next key = previous ciphertext byte
      buffer.add(plain);
    }
    return const Utf8Decoder().convert(buffer);
  }

  // -----------------------------------------------------------------------
  // TCP transport
  // -----------------------------------------------------------------------

  /// Opens a TCP connection to the device, sends the [command] JSON, waits for
  /// the response, decodes it and returns the parsed map.
  Future<Map<String, dynamic>> _sendCommand(String command) async {
    final encrypted = encrypt(command);
    late Socket socket;

    try {
      socket = await Socket.connect(_ipAddress, _port, timeout: _timeout);
    } catch (e) {
      throw DriverCommandException(
        'KasaDriver: cannot connect to $_ipAddress:$_port',
        cause: e,
      );
    }

    try {
      final completer = Completer<Uint8List>();
      final chunks = <int>[];

      socket.listen(
        chunks.addAll,
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(Uint8List.fromList(chunks));
          }
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) {
            completer.completeError(
              DriverCommandException('KasaDriver TCP error', cause: e),
              st,
            );
          }
        },
        cancelOnError: true,
      );

      socket.add(encrypted);
      await socket.flush();

      final responseBytes = await completer.future.timeout(
        _timeout,
        onTimeout: () =>
            throw DriverCommandException('KasaDriver: response timeout'),
      );

      if (responseBytes.length < 4) {
        throw DriverCommandException('KasaDriver: invalid response header');
      }
      final expectedLength =
          (responseBytes[0] << 24) |
          (responseBytes[1] << 16) |
          (responseBytes[2] << 8) |
          responseBytes[3];
      if (expectedLength < 0 || expectedLength > _maxPayloadBytes) {
        throw DriverCommandException('KasaDriver: response payload too large');
      }
      if (responseBytes.length - 4 < expectedLength) {
        throw DriverCommandException('KasaDriver: truncated response payload');
      }

      final payload = Uint8List.sublistView(responseBytes, 0, 4 + expectedLength);
      final responseJson = decrypt(payload);
      try {
        return jsonDecode(responseJson) as Map<String, dynamic>;
      } catch (e) {
        throw DriverCommandException(
          'KasaDriver: failed to parse JSON response',
          cause: e,
        );
      }
    } finally {
      socket.destroy();
    }
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _assertInit() {
    if (!_initialized) {
      throw StateError('KasaDriver.initialize() must be called first.');
    }
  }

  static Map<String, dynamic>? _extractNested(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    dynamic current = data;
    for (final key in keys) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current as Map<String, dynamic>?;
  }
}
