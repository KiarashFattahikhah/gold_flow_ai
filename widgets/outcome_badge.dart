import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OutcomeBadge extends StatelessWidget {
  final String outcome;

  const OutcomeBadge({super.key, required this.outcome});

  Color _color() {
    if (outcome.startsWith('✅')) return AppColors.buy;
    if (outcome.contains('Missed move')) return AppColors.sell;
    if (outcome.startsWith('❌')) return AppColors.sell;
    if (outcome.contains('Pending')) return AppColors.textSecondary;
    if (outcome.contains('No data')) return AppColors.textSecondary;
    return AppColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final label = outcome.isEmpty ? '—' : outcome;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
