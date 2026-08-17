// static const String defaultBaseUrl = 'https://venue-lubricant-cruelly.ngrok-free.dev/api/signals';
// static const String defaultBaseUrl = 'http://192.168.230.202:8000/api/signals';
import 'dart:async';

import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/signal_row.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Talks to the trading-signal backend.
///
/// Contract expected of the server: a GET endpoint that returns the
/// contents of `live_signal_log.csv` (see project README) as
/// `Content-Type: text/csv`, newest rows first or in any order — this
/// client sorts client-side. The endpoint should reflect the latest
/// signals in near-real time (the app polls it on an interval).
class ApiService {
  static const _prefKeyBaseUrl = 'api_base_url';

  // TODO: replace with your real, always-on server address, e.g.
  // 'https://your-domain.com/api/signals' or your deployed
  // example_server.py's public URL. This is used automatically —
  // users never have to type anything.
  // static const String defaultBaseUrl = 'https://venue-lubricant-cruelly.ngrok-free.dev/api/signals';
  // static const String defaultBaseUrl = 'https://squander-truffle-hypocrite.ngrok-free.dev/api/signals';
  static const String defaultBaseUrl = 'https://desktop-p97ss8r.tail8f55ff.ts.net/api/signals';

  Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKeyBaseUrl);
    if (stored != null && stored.isNotEmpty) return stored;
    return defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, url.trim());
  }

  Future<List<SignalRow>> fetchSignals() async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.trim().isEmpty) {
      throw ApiException('No API endpoint configured yet. Set it from the Settings icon.');
    }

    final Uri uri;
    try {
      uri = Uri.parse(baseUrl.trim());
    } catch (_) {
      throw ApiException('The configured API URL is not valid.');
    }

    late http.Response response;
    try {
      response = await http
          .get(uri, headers: const {'Accept': 'text/csv'})
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException(
          'Server took too long to respond (>30s). If it logged 200 anyway, the response arrived after the client gave up — check tunnel/network latency.');
    } catch (e) {
      throw ApiException('Could not reach the server ($e). Check the URL and your connection.');
    }

    if (response.statusCode != 200) {
      throw ApiException('Server returned HTTP ${response.statusCode}.');
    }

    return parseCsv(response.body);
  }

  /// Parses raw CSV text (matching the columns documented in the pipeline
  /// README) into a list of [SignalRow], newest first.
  List<SignalRow> parseCsv(String csvText) {
    // Strip a UTF-8 BOM if present — common on files exported from pandas.
    var text = csvText;
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    if (text.trim().isEmpty) return [];

    final table = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
    if (table.isEmpty) return [];

    final headers = table.first.map((h) => h.toString().trim()).toList();
    final rows = <SignalRow>[];

    for (final rawRow in table.skip(1)) {
      if (rawRow.isEmpty || (rawRow.length == 1 && rawRow.first.toString().trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (var i = 0; i < headers.length && i < rawRow.length; i++) {
        map[headers[i]] = rawRow[i]?.toString() ?? '';
      }
      try {
        rows.add(SignalRow.fromMap(map));
      } catch (_) {
        continue; // skip rows with an invalid/missing timestamp rather than mis-dating them
      }
    }

    rows.sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    return rows;
  }
}