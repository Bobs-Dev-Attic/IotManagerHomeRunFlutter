import 'dart:developer' as developer;

/// Thin wrapper around dart:developer's log function.
///
/// Replace the body of each method with your preferred logging library
/// (e.g. `logger` package) without changing any call sites.
class AppLogger {
  AppLogger._();

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'IotManager',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[WARNING] $message',
      name: 'IotManager',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[ERROR] $message',
      name: 'IotManager',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void debug(String message) {
    assert(() {
      developer.log('[DEBUG] $message', name: 'IotManager');
      return true;
    }());
  }
}
