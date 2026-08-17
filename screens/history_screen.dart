import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/horizon_stats.dart';
import '../models/signal_row.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/price_band.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _api = ApiService();

  List<SignalRow> _rows = [];
  bool _loading = true;
  String? _error;
  int? _horizonFilter; // null == all

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
    final horizons = distinctHorizons(_rows);
    final visibleRows =
        _horizonFilter == null ? _rows : _rows.where((r) => r.horizonMinutes == _horizonFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (horizons.length > 1) _buildFilterBar(horizons),
            Expanded(child: _buildList(visibleRows)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(List<int> horizons) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
                label: 'All',
                selected: _horizonFilter == null,
                onTap: () => setState(() => _horizonFilter = null)),
            const SizedBox(width: 8),
            for (final h in horizons) ...[
              _filterChip(
                label: '${h}m',
                selected: _horizonFilter == h,
                onTap: () => setState(() => _horizonFilter = h),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required bool selected, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.gold.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? AppColors.gold : AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide(color: selected ? AppColors.gold : AppColors.divider),
    );
  }

  Widget _buildList(List<SignalRow> rows) {
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
              Text(_error!, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text('No signal history yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceRaised,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _HistoryRowTile(row: rows[i]),
      ),
    );
  }
}

class _HistoryRowTile extends StatelessWidget {
  final SignalRow row;

  const _HistoryRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final signalColor = colorForSignal(row.signal);
    final priceFmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('MMM d, HH:mm:ss');
    final band = priceBandFor(row.horizonMinutes, row.predictedClose);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${row.horizonMinutes}m',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(iconForSignal(row.signal), color: signalColor, size: 15),
                const SizedBox(width: 4),
                Text(
                  row.signal.isEmpty ? 'UNKNOWN' : row.signal,
                  style: TextStyle(color: signalColor, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
                const Spacer(),
                Text(
                  '${dateFmt.format(row.timestampUtc)} UTC',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _kv('Current', '\$${priceFmt.format(row.currentClose)}'),
                ),
                Expanded(
                  flex: 2,
                  child: _kv(
                    'Predicted',
                    band == null
                        ? '\$${priceFmt.format(row.predictedClose)}'
                        : '\$${priceFmt.format(band.low)} \u2013 \$${priceFmt.format(band.high)}',
                  ),
                ),
                Expanded(
                  child: _kv('Confidence', '${row.confidence.toStringAsFixed(1)}%'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${row.predictedChangePct >= 0 ? '+' : ''}${row.predictedChangePct.toStringAsFixed(3)}% predicted',
                  style: TextStyle(
                    color: row.predictedChangePct >= 0 ? AppColors.buy : AppColors.sell,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (row.ticker.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      row.ticker,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}