import 'package:flutter/material.dart';

/// Visual language for the app: a dark, focused "trading terminal" feel
/// with a gold accent, tuned for scanning numbers quickly at a glance.
class AppColors {
  static const background = Color(0xFF0B0E13);
  static const surface = Color(0xFF151A22);
  static const surfaceRaised = Color(0xFF1D242F);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFE9CD6A);
  static const textPrimary = Color(0xFFEDEFF3);
  static const textSecondary = Color(0xFF8A93A3);
  static const buy = Color(0xFF2FBF71);
  static const sell = Color(0xFFE5484D);
  static const neutral = Color(0xFFF5A623);
  static const divider = Color(0xFF262E3A);
}

Color colorForSignal(String signal) {
  final s = signal.trim().toUpperCase();
  if (s == 'BUY') return AppColors.buy;
  if (s == 'SELL') return AppColors.sell;
  return AppColors.neutral; // DO NOTHING / unknown
}

IconData iconForSignal(String signal) {
  final s = signal.trim().toUpperCase();
  if (s == 'BUY') return Icons.trending_up_rounded;
  if (s == 'SELL') return Icons.trending_down_rounded;
  return Icons.horizontal_rule_rounded;
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.gold,
      secondary: AppColors.goldSoft,
      surface: AppColors.surface,
      error: AppColors.sell,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerColor: AppColors.divider,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: AppColors.surfaceRaised,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceRaised,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
