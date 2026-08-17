import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gold_trading/screens/chart_screen.dart';
import 'package:intl/intl.dart';

import '../models/horizon_stats.dart';
import '../models/signal_row.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/signal_card.dart';
import 'history_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../auth/reauth_dialog.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  Timer? _pollTimer;

  List<SignalRow> _rows = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  bool _requestingRun = false;

  static const _pollInterval = Duration(seconds: 30);

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // getBaseUrl() now always returns a value (the hardcoded default if
    // nothing else was set), so there's no "not configured" state anymore
    // — connection happens automatically.
    await _refresh();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _refresh(silent: true));
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows = await _api.fetchSignals();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _requestNewSignals() async {
    setState(() => _requestingRun = true);
    try {
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error == null ? 'Latest signals loaded.' : _error!)),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingRun = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    // AuthGate's stream picks this up and shows LoginPage automatically.
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Delete account?'),
        content: const Text(
          "This permanently deletes your account and can't be undone.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sell),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _authService.deleteAccount();
      // AuthGate's stream picks this up and shows RegisterPage automatically.
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        final password = await promptForPassword(context);
        if (password == null || password.isEmpty) return;
        try {
          await _authService.reauthenticate(password);
          await _authService.deleteAccount();
        } on AuthException catch (e2) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e2.message)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? 'Could not delete account.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizons = distinctHorizons(_rows);
    final horizon5 = horizons.contains(5) ? 5 : (horizons.isNotEmpty ? horizons.first : 5);
    final horizon15 = horizons.contains(15) ? 15 : (horizons.length > 1 ? horizons[1] : 15);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gold Signal Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Price Range Chart',
            icon: const Icon(Icons.show_chart_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChartScreen()),
            ),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'delete') _confirmDeleteAccount();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text('Log out')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete account', style: TextStyle(color: AppColors.sell)),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(horizon5, horizon15)),
    );
  }

  Widget _buildBody(int horizon5, int horizon15) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return _emptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load signals',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _refresh(),
      );
    }

    final latest5 = latestSignalForHorizon(_rows, horizon5);
    final latest15 = latestSignalForHorizon(_rows, horizon15);

    return RefreshIndicator(
      onRefresh: () => _refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.surfaceRaised,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _inlineWarning(_error!),
            ),
          FilledButton.icon(
            onPressed: _requestingRun ? null : _requestNewSignals,
            icon: _requestingRun
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_requestingRun ? 'Checking…' : 'Check for New Signals'),
          ),
          const SizedBox(height: 20),
          if (_lastUpdated != null)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'updated ${DateFormat('HH:mm:ss').format(_lastUpdated!)} UTC',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: AppColors.gold),
              SizedBox(width: 6),
              Text(
                'LATEST SIGNALS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SignalCard(horizonMinutes: horizon5, row: latest5),
          const SizedBox(height: 12),
          SignalCard(horizonMinutes: horizon15, row: latest15),
        ],
      ),
    );
  }

  Widget _inlineWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sell.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sell.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.sell, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing last known data — $message',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}