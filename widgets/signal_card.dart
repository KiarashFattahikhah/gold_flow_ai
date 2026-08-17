import 'package:flutter/material.dart';
import 'package:gold_trading/utils/price_band.dart';
import 'package:intl/intl.dart';

import '../models/signal_row.dart';
import '../theme/app_theme.dart';

class SignalCard extends StatelessWidget {
  final int horizonMinutes;
  final SignalRow? row;

  const SignalCard({super.key, required this.horizonMinutes, required this.row});

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty_rounded, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                'No $horizonMinutes-minute signal yet',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final signalColor = colorForSignal(row!.signal);
    final priceFmt = NumberFormat('#,##0.00');
    final timeFmt = DateFormat('HH:mm:ss');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${row!.horizonMinutes}m',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Text(
                  'as of ${timeFmt.format(row!.timestampUtc)} GMT',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: signalColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: signalColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconForSignal(row!.signal), color: signalColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        row!.signal.isEmpty ? 'UNKNOWN' : row!.signal,
                        style: TextStyle(
                          color: signalColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _metric(
                    label: 'PREDICTED PRICE',
                    value: () {
                      final band = priceBandFor(row!.horizonMinutes, row!.predictedClose);
                      if (band == null) return '\$${priceFmt.format(row!.predictedClose)}';
                      return '\$${priceFmt.format(band.low)} – \$${priceFmt.format(band.high)}';
                    }(),
                    sub:
                        '${row!.predictedChangePct >= 0 ? '+' : ''}${row!.predictedChangePct.toStringAsFixed(3)}%',
                    subColor: row!.predictedChangePct >= 0 ? AppColors.buy : AppColors.sell,
                  ),
                ),
                Expanded(
                  child: _metric(
                    label: 'CURRENT PRICE',
                    value: '\$${priceFmt.format(row!.currentClose)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'CONFIDENCE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  '${row!.confidence.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (row!.confidence.clamp(0, 100)) / 100,
                minHeight: 8,
                backgroundColor: AppColors.surfaceRaised,
                valueColor: AlwaysStoppedAnimation(signalColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric({required String label, required String value, String? sub, Color? subColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(color: subColor ?? AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}