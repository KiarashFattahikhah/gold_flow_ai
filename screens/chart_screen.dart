import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/signal_row.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/price_band.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _api = ApiService();
  List<SignalRow> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchSignals();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Price Chart'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceRaised,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HorizonPriceChart(horizonMinutes: 5, rows: _rows),
          const SizedBox(height: 24),
          _HorizonPriceChart(horizonMinutes: 15, rows: _rows),
        ],
      ),
    );
  }
}

class _HorizonPriceChart extends StatelessWidget {
  final int horizonMinutes;
  final List<SignalRow> rows;

  const _HorizonPriceChart({required this.horizonMinutes, required this.rows});

  static const _idxActual = 0;
  static const _idxActualProjection = 1;
  static const _idxLow = 2;
  static const _idxLowProjection = 3;
  static const _idxHigh = 4;
  static const _idxHighProjection = 5;

  @override
  Widget build(BuildContext context) {
    final horizonRows = rows.where((r) => r.horizonMinutes == horizonMinutes).toList()
      ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));

    final halfWidth = horizonPriceBandHalfWidth[horizonMinutes];

    if (horizonRows.isEmpty || halfWidth == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No $horizonMinutes-minute data yet.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // fl_chart picks its own "nice" tick spacing internally, and that math
    // isn't built for values as large as raw millisecondsSinceEpoch
    // (~1.7 trillion) — it produces tick positions that don't line up with
    // real, evenly-spaced timestamps, which is why axis labels come out
    // scrambled. Fix: use minutes-since-origin as the x domain (small,
    // well-behaved numbers) and convert back to real time only for display.
    final origin = horizonRows.first.timestampUtc;
    double xFor(DateTime t) => t.difference(origin).inMilliseconds / 60000.0;
    DateTime timeForX(double x) => origin.add(Duration(milliseconds: (x * 60000).round()));

    // The actual price series: currentClose is the real observed price at
    // each row's timestamp, so this is a solid line of true readings.
    final actualSpots = <FlSpot>[
      for (final r in horizonRows) FlSpot(xFor(r.timestampUtc), r.currentClose),
    ];

    // The high/low band: every row already carries its own predictedClose,
    // so the band is a real historical series too, not just a single point
    // at the end — plotted solid, right alongside the actual price.
    final lowSpots = <FlSpot>[
      for (final r in horizonRows) FlSpot(xFor(r.timestampUtc), r.predictedClose - halfWidth),
    ];
    final highSpots = <FlSpot>[
      for (final r in horizonRows) FlSpot(xFor(r.timestampUtc), r.predictedClose + halfWidth),
    ];

    // Projection: the only part we don't have real data for yet — from the
    // last known point out to that latest prediction's target time — hence
    // dashed. Actual converges toward the model's own median forecast;
    // high/low continue flat at their last known band.
    final last = horizonRows.last;
    final lastX = xFor(last.timestampUtc);
    final targetTime = last.targetTimestampUtc ?? last.timestampUtc.add(Duration(minutes: horizonMinutes));
    final targetX = xFor(targetTime);
    final forecastLow = last.predictedClose - halfWidth;
    final forecastHigh = last.predictedClose + halfWidth;

    final actualProjectionSpots = [FlSpot(lastX, last.currentClose), FlSpot(targetX, last.predictedClose)];
    final lowProjectionSpots = [FlSpot(lastX, forecastLow), FlSpot(targetX, forecastLow)];
    final highProjectionSpots = [FlSpot(lastX, forecastHigh), FlSpot(targetX, forecastHigh)];

    final allY = [
      ...actualSpots.map((s) => s.y),
      ...lowSpots.map((s) => s.y),
      ...highSpots.map((s) => s.y),
      last.predictedClose,
    ];
    final minY = allY.reduce((a, b) => a < b ? a : b);
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final yPadding = ((maxY - minY) * 0.15).clamp(0.5, double.infinity);

    final minX = actualSpots.first.x;
    final maxX = targetX;
    final xRange = (maxX - minX) > 0 ? (maxX - minX) : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_rounded, color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${horizonMinutes}m PRICE — ACTUAL & FORECAST RANGE (\u00b1${halfWidth.toStringAsFixed(2)})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY - yPadding,
                  maxY: maxY + yPadding,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: ((maxY - minY) + yPadding * 2) / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (value, meta) => Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: xRange / 3,
                        getTitlesWidget: (value, meta) {
                          final dt = timeForX(value);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('HH:mm').format(dt),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final dt = timeForX(s.x);
                        final label = switch (s.barIndex) {
                          _idxActual || _idxActualProjection => 'Actual',
                          _idxLow || _idxLowProjection => 'Low',
                          _idxHigh || _idxHighProjection => 'High',
                          _ => '',
                        };
                        return LineTooltipItem(
                          '$label \$${s.y.toStringAsFixed(2)}\n${DateFormat('MMM d HH:mm').format(dt)} UTC',
                          const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    // index 0 — Actual price (solid, real data, may fluctuate)
                    LineChartBarData(
                      spots: actualSpots,
                      isCurved: false,
                      color: AppColors.textPrimary,
                      barWidth: 2,
                      dotData: FlDotData(show: actualSpots.length <= 1),
                    ),
                    // index 1 — Actual → projected median (dashed, unrealized)
                    LineChartBarData(
                      spots: actualProjectionSpots,
                      isCurved: false,
                      color: AppColors.textPrimary,
                      barWidth: 2,
                      dashArray: const [4, 3],
                      dotData: const FlDotData(show: false),
                    ),
                    // index 2 — Low band (solid, one point per row's own prediction)
                    LineChartBarData(
                      spots: lowSpots,
                      isCurved: false,
                      color: AppColors.sell,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    // index 3 — Low band projection (dashed, unrealized)
                    LineChartBarData(
                      spots: lowProjectionSpots,
                      isCurved: false,
                      color: AppColors.sell,
                      barWidth: 2,
                      dashArray: const [4, 3],
                      dotData: const FlDotData(show: false),
                    ),
                    // index 4 — High band (solid, one point per row's own prediction)
                    LineChartBarData(
                      spots: highSpots,
                      isCurved: false,
                      color: AppColors.buy,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    // index 5 — High band projection (dashed, unrealized)
                    LineChartBarData(
                      spots: highProjectionSpots,
                      isCurved: false,
                      color: AppColors.buy,
                      barWidth: 2,
                      dashArray: const [4, 3],
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _legendDot(AppColors.textPrimary, 'Current'),
                _legendDot(AppColors.buy, 'High'),
                _legendDot(AppColors.sell, 'Low'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}