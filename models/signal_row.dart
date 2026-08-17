/// A single row from the live_signal_log.csv exposed by the backend API.
///
/// Mirrors the columns documented in the pipeline README:
/// timestamp_utc, data_as_of, horizon_minutes, ticker, current_close,
/// predicted_close, predicted_change_pct, confidence, signal,
/// target_timestamp_utc, actual_close, actual_change_pct, outcome
class SignalRow {
  final DateTime timestampUtc;
  final DateTime? dataAsOf;
  final int horizonMinutes;
  final String ticker;
  final double currentClose;
  final double predictedClose;
  final double predictedChangePct;
  final double confidence;
  final String signal;
  final DateTime? targetTimestampUtc;
  final double? actualClose;
  final double? actualChangePct;
  final String outcome;

  SignalRow({
    required this.timestampUtc,
    required this.dataAsOf,
    required this.horizonMinutes,
    required this.ticker,
    required this.currentClose,
    required this.predictedClose,
    required this.predictedChangePct,
    required this.confidence,
    required this.signal,
    required this.targetTimestampUtc,
    required this.actualClose,
    required this.actualChangePct,
    required this.outcome,
  });

  /// Builds a [SignalRow] from a header->value map for one CSV line.
  /// Every field is parsed defensively since live feeds occasionally emit
  /// blank/partial values (e.g. actual_close before a prediction resolves).
  factory SignalRow.fromMap(Map<String, String> map) {
    return SignalRow(
      timestampUtc: _parseDate(map['timestamp_utc']) ?? DateTime.now().toUtc(),
      dataAsOf: _parseDate(map['data_as_of']),
      horizonMinutes: _parseInt(map['horizon_minutes']) ?? 0,
      ticker: (map['ticker'] ?? '').trim(),
      currentClose: _parseDouble(map['current_close']) ?? 0,
      predictedClose: _parseDouble(map['predicted_close']) ?? 0,
      predictedChangePct: _parseDouble(map['predicted_change_pct']) ?? 0,
      confidence: _parseDouble(map['confidence']) ?? 0,
      signal: (map['signal'] ?? '').trim(),
      targetTimestampUtc: _parseDate(map['target_timestamp_utc']),
      actualClose: _parseDouble(map['actual_close']),
      actualChangePct: _parseDouble(map['actual_change_pct']),
      outcome: (map['outcome'] ?? '').trim(),
    );
  }

  bool get isCorrect => outcome.startsWith('✅');
  bool get isMissedMove => outcome.contains('Missed move');
  bool get isPending => outcome.contains('Pending');
  bool get isUnresolved =>
      outcome.contains('No data') || outcome.contains('Pending') || outcome.isEmpty;

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim()).toUtc();
    } catch (_) {
      return null;
    }
  }

  static double? _parseDouble(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return double.tryParse(raw.trim());
  }

  static int? _parseInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }
}
