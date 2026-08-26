import 'package:flutter/foundation.dart';

/// Lightweight, debug-only performance markers. Release builds do not emit
/// these diagnostics and no URLs, credentials, or user content are recorded.
class PerformanceMetrics {
  PerformanceMetrics._();

  static final Stopwatch _startup = Stopwatch()..start();

  static void mark(String name, {Duration? elapsed}) {
    if (!kDebugMode) return;
    final suffix =
        elapsed == null ? '' : ' elapsed_ms=${elapsed.inMilliseconds}';
    debugPrint('[perf] $name t_ms=${_startup.elapsedMilliseconds}$suffix');
  }

  static T measure<T>(String name, T Function() action) {
    if (!kDebugMode) return action();
    final watch = Stopwatch()..start();
    try {
      return action();
    } finally {
      mark(name, elapsed: watch.elapsed);
    }
  }

  static Future<T> measureAsync<T>(
      String name, Future<T> Function() action) async {
    if (!kDebugMode) return action();
    final watch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      mark(name, elapsed: watch.elapsed);
    }
  }
}
