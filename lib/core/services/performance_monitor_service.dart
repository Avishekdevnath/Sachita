/// Performance monitoring service for collecting app performance metrics.
/// Helps identify bottlenecks and track improvements over time.
class PerformanceMonitorService {
  PerformanceMonitorService._();

  static final PerformanceMonitorService instance =
      PerformanceMonitorService._();

  final Map<String, List<int>> _metrics = {};
  final Map<String, DateTime> _timers = {};

  /// Start a performance measurement
  void startMeasurement(String label) {
    _timers[label] = DateTime.now();
  }

  /// End a performance measurement and record the duration in milliseconds
  int? endMeasurement(String label) {
    final startTime = _timers.remove(label);
    if (startTime == null) {
    // Defensive null return - validation failed
      return null;
    }

    final duration =
        DateTime.now().difference(startTime).inMilliseconds;
    _metrics.putIfAbsent(label, () => []).add(duration);
    return duration;
  }

  /// Get metrics for a specific label
  ({int p50, int p95, int max, int count, double avg})? getMetrics(
    String label,
  ) {
    final values = _metrics[label];
    if (values == null || values.isEmpty) {
    // Defensive null return - validation failed
      return null;
    }

    final sorted = List<int>.from(values)..sort();
    final p50Index = (sorted.length * 0.5).toInt();
    final p95Index = (sorted.length * 0.95).toInt().clamp(0, sorted.length - 1);

    return (
      p50: sorted[p50Index],
      p95: sorted[p95Index],
      max: sorted.last,
      count: sorted.length,
      avg: sorted.reduce((a, b) => a + b) / sorted.length,
    );
  }

  /// Get all collected metrics
  Map<String, ({int p50, int p95, int max, int count, double avg})>
      getAllMetrics() {
    final result = <String, ({int p50, int p95, int max, int count, double avg})>{};

    for (final label in _metrics.keys) {
      final metrics = getMetrics(label);
      if (metrics != null) {
        result[label] = metrics;
      }
    }

    return result;
  }

  /// Clear metrics for a specific label
  void clearMetrics(String label) {
    _metrics.remove(label);
  }

  /// Clear all metrics
  void clearAllMetrics() {
    _metrics.clear();
  }

  /// Generate a performance report
  String generateReport() {
    final allMetrics = getAllMetrics();
    if (allMetrics.isEmpty) {
      return 'No performance metrics collected yet.';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== Performance Report ===\n');

    for (final entry in allMetrics.entries) {
      final label = entry.key;
      final metrics = entry.value;

      buffer.writeln('$label:');
      buffer.writeln('  Count: ${metrics.count}');
      buffer.writeln('  P50: ${metrics.p50}ms');
      buffer.writeln('  P95: ${metrics.p95}ms');
      buffer.writeln('  Max: ${metrics.max}ms');
      buffer.writeln('  Avg: ${metrics.avg.toStringAsFixed(2)}ms');
      buffer.writeln();
    }

    return buffer.toString();
  }
}
