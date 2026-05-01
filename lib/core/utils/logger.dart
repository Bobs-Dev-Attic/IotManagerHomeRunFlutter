import 'dart:developer' as developer;

class AppLogger {
  AppLogger._();

  static const _sensitivePatterns = [
    'password',
    'token',
    'secret',
    'authorization',
    'apiKey',
    'apikey',
    'bearer',
    'meshKey',
  ];

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(_redact(message), name: 'IotManager', error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log('[WARNING] ${_redact(message)}', name: 'IotManager', error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log('[ERROR] ${_redact(message)}', name: 'IotManager', error: error, stackTrace: stackTrace);
  }

  static void debug(String message) {
    assert(() {
      developer.log('[DEBUG] ${_redact(message)}', name: 'IotManager');
      return true;
    }());
  }

  static String _redact(String input) {
    var output = input;
    for (final key in _sensitivePatterns) {
      final pattern = RegExp('($key\\s*[:=]\\s*)([^,\\s]+)', caseSensitive: false);
      output = output.replaceAllMapped(pattern, (m) => '${m.group(1)}[REDACTED]');
    }
    return output;
  }
}
