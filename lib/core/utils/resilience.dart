import 'dart:math';

typedef AsyncTask<T> = Future<T> Function();

class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 3,
    this.openDuration = const Duration(seconds: 30),
  });

  final int failureThreshold;
  final Duration openDuration;

  int _failures = 0;
  DateTime? _openedAt;

  bool get isOpen {
    final opened = _openedAt;
    if (opened == null) return false;
    if (DateTime.now().difference(opened) >= openDuration) {
      _openedAt = null;
      _failures = 0;
      return false;
    }
    return true;
  }

  Future<T> run<T>(AsyncTask<T> task) async {
    if (isOpen) {
      throw StateError('Circuit breaker is open. Try again later.');
    }
    try {
      final result = await task();
      _failures = 0;
      return result;
    } catch (_) {
      _failures++;
      if (_failures >= failureThreshold) {
        _openedAt = DateTime.now();
      }
      rethrow;
    }
  }
}

Future<T> retryWithBackoff<T>({
  required AsyncTask<T> task,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 250),
  double jitterFactor = 0.25,
}) async {
  final random = Random();
  var attempt = 0;
  var delay = initialDelay;

  while (true) {
    attempt++;
    try {
      return await task();
    } catch (_) {
      if (attempt >= maxAttempts) rethrow;
      final jitter = (delay.inMilliseconds * jitterFactor * random.nextDouble()).round();
      await Future<void>.delayed(Duration(milliseconds: delay.inMilliseconds + jitter));
      delay *= 2;
    }
  }
}
