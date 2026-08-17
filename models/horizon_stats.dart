import 'signal_row.dart';

/// Aggregated accuracy for one forecast horizon (e.g. 5 or 15 minutes).
///
/// Accuracy is defined the way the dashboard README defines it: only
/// resolved predictions count, and a resolved prediction is either
/// "✅ Correct..." or "⚠️ Missed move" — pending / no-data rows are ignored.
class HorizonStats {
  final int horizonMinutes;
  final int corrects;
  final int missed;

  HorizonStats({
    required this.horizonMinutes,
    required this.corrects,
    required this.missed,
  });

  int get resolved => corrects + missed;

  /// corrects / (corrects + missed) — null when nothing has resolved yet.
  double? get accuracy => resolved == 0 ? null : corrects / resolved;

  factory HorizonStats.fromRows(int horizonMinutes, List<SignalRow> rows) {
    final subset = rows.where((r) => r.horizonMinutes == horizonMinutes);
    final corrects = subset.where((r) => r.isCorrect).length;
    final missed = subset.where((r) => r.isMissedMove).length;
    return HorizonStats(horizonMinutes: horizonMinutes, corrects: corrects, missed: missed);
  }
}

/// Returns the most recent [SignalRow] for [horizonMinutes], or null if none.
SignalRow? latestSignalForHorizon(List<SignalRow> rows, int horizonMinutes) {
  final subset = rows.where((r) => r.horizonMinutes == horizonMinutes).toList();
  if (subset.isEmpty) return null;
  subset.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
  return subset.first;
}

/// Distinct horizons present in the data, sorted ascending.
List<int> distinctHorizons(List<SignalRow> rows) {
  final set = rows.map((r) => r.horizonMinutes).toSet().toList();
  set.sort();
  return set;
}
