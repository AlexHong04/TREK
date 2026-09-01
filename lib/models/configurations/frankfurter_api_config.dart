import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrankfurterApiException implements Exception {
  final String message;

  const FrankfurterApiException(this.message);

  @override
  String toString() => 'FrankfurterApiException: $message';
}

/// Shared access to Frankfurter currency codes and exchange-rate values.
///
/// Frankfurter returns reference rates, not payment-provider transaction rates.
/// Currency codes and values are fetched by separate functions and cached in
/// SharedPreferences so every TREK module can reuse them without another call.
class FrankfurterApiConfig {
  FrankfurterApiConfig._();

  static const String baseUrl = 'https://api.frankfurter.dev/v2';
  static const String defaultBaseCurrency = 'USD';

  static const String _currencyCodesKey =
      'trek.frankfurter.active_currency_codes';
  static const String _currencyCodesUpdatedAtKey =
      'trek.frankfurter.currency_codes_updated_at';
  static const String _ratesKeyPrefix = 'trek.frankfurter.rates.';
  static const String _ratesDateKeyPrefix = 'trek.frankfurter.rates_date.';
  static const String _ratesUpdatedAtKeyPrefix =
      'trek.frankfurter.rates_updated_at.';

  static const Duration cacheDuration = Duration(hours: 12);
  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  /// Warms both caches without preventing TREK from starting while offline.
  static Future<void> initialize() async {
    try {
      await Future.wait([
        getCurrencyCodes(),
        getCurrencyValues(),
      ]);
    } catch (_) {
      // The public getters still surface errors when a caller requires data.
    }
  }

  /// Fetches and caches active ISO currency codes such as USD, MYR and EUR.
  static Future<List<String>> fetchCurrencyCodes() async {
    final response = await http
        .get(Uri.parse('$baseUrl/currencies'))
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FrankfurterApiException(
        'The currencies response has an unexpected format.',
      );
    }

    final codes = decoded
        .whereType<Map>()
        .map((item) => item['iso_code']?.toString().trim().toUpperCase())
        .whereType<String>()
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (!codes.contains('USD') || !codes.contains('MYR')) {
      throw const FrankfurterApiException(
        'Frankfurter did not return the required USD and MYR currencies.',
      );
    }

    await _preferences.setStringList(_currencyCodesKey, codes);
    await _preferences.setString(
      _currencyCodesUpdatedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    return List<String>.unmodifiable(codes);
  }

  /// Fetches and caches the latest numeric values for one base currency.
  ///
  /// Example with USD as base: a MYR value of 4.45 means USD 1 = MYR 4.45.
  static Future<Map<String, double>> fetchCurrencyValues({
    String baseCurrency = defaultBaseCurrency,
    Iterable<String>? quoteCurrencies,
  }) async {
    final base = _normalizeCode(baseCurrency);
    final quotes = quoteCurrencies
        ?.map(_normalizeCode)
        .where((code) => code != base)
        .toSet()
        .toList()
      ?..sort();

    final uri = Uri.parse('$baseUrl/rates').replace(
      queryParameters: {
        'base': base,
        if (quotes != null && quotes.isNotEmpty) 'quotes': quotes.join(','),
      },
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 15));
    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FrankfurterApiException(
        'The rates response has an unexpected format.',
      );
    }

    final values = <String, double>{base: 1.0};
    String? rateDate;
    for (final item in decoded.whereType<Map>()) {
      final quote = item['quote']?.toString().trim().toUpperCase();
      final rate = item['rate'];
      if (quote == null || quote.isEmpty || rate is! num || rate <= 0) {
        continue;
      }
      values[quote] = rate.toDouble();
      rateDate ??= item['date']?.toString();
    }

    if (values.length == 1 &&
        (quotes == null || quotes.any((quote) => quote != base))) {
      throw const FrankfurterApiException(
        'Frankfurter returned no usable exchange-rate values.',
      );
    }

    await _preferences.setString(_ratesKey(base), jsonEncode(values));
    if (rateDate != null) {
      await _preferences.setString(_ratesDateKey(base), rateDate);
    }
    await _preferences.setString(
      _ratesUpdatedAtKey(base),
      DateTime.now().toUtc().toIso8601String(),
    );
    return Map<String, double>.unmodifiable(values);
  }

  /// Returns cached codes immediately when fresh, otherwise refreshes them.
  /// If refresh fails, an existing cache is returned for offline use.
  static Future<List<String>> getCurrencyCodes({
    bool forceRefresh = false,
  }) async {
    final cached = await _preferences.getStringList(_currencyCodesKey);
    final isFresh = await _isFresh(_currencyCodesUpdatedAtKey);
    if (!forceRefresh && cached != null && cached.isNotEmpty && isFresh) {
      return List<String>.unmodifiable(cached);
    }

    try {
      return await fetchCurrencyCodes();
    } catch (_) {
      if (cached != null && cached.isNotEmpty) {
        return List<String>.unmodifiable(cached);
      }
      rethrow;
    }
  }

  /// Returns cached values immediately when fresh, otherwise refreshes them.
  /// If refresh fails, an existing cache is returned for offline use.
  static Future<Map<String, double>> getCurrencyValues({
    String baseCurrency = defaultBaseCurrency,
    bool forceRefresh = false,
  }) async {
    final base = _normalizeCode(baseCurrency);
    final cached = await _readCachedValues(base);
    final isFresh = await _isFresh(_ratesUpdatedAtKey(base));
    if (!forceRefresh && cached.isNotEmpty && isFresh) {
      return Map<String, double>.unmodifiable(cached);
    }

    try {
      return await fetchCurrencyValues(baseCurrency: base);
    } catch (_) {
      if (cached.isNotEmpty) {
        return Map<String, double>.unmodifiable(cached);
      }
      rethrow;
    }
  }

  /// Refreshes both independent caches. Call once during app start.
  static Future<void> refreshCurrencyCache({
    String baseCurrency = defaultBaseCurrency,
  }) async {
    await fetchCurrencyCodes();
    await fetchCurrencyValues(baseCurrency: baseCurrency);
  }

  /// Gets one cross-currency value using a cached base-rate table.
  static Future<double?> getRate({
    required String fromCurrency,
    required String toCurrency,
    String cachedBaseCurrency = defaultBaseCurrency,
  }) async {
    final from = _normalizeCode(fromCurrency);
    final to = _normalizeCode(toCurrency);
    final base = _normalizeCode(cachedBaseCurrency);
    if (from == to) return 1.0;

    final values = await getCurrencyValues(baseCurrency: base);
    final fromValue = from == base ? 1.0 : values[from];
    final toValue = to == base ? 1.0 : values[to];
    if (fromValue == null || toValue == null || fromValue == 0) return null;
    return toValue / fromValue;
  }

  static Future<double?> convertAmount({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final normalizedFrom = _normalizeCode(fromCurrency);
    final normalizedTo = _normalizeCode(toCurrency);

    if (normalizedFrom == normalizedTo) {
      return amount;
    }

    final rate = await getRate(
      fromCurrency: normalizedFrom,
      toCurrency: normalizedTo,
    );

    return rate == null ? null : amount * rate;
  }

  static Future<String?> getRateDate({
    String baseCurrency = defaultBaseCurrency,
  }) {
    return _preferences.getString(
      _ratesDateKey(_normalizeCode(baseCurrency)),
    );
  }

  static Future<Map<String, double>> _readCachedValues(String base) async {
    final encoded = await _preferences.getString(_ratesKey(base));
    if (encoded == null || encoded.isEmpty) return const {};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const {};
      return decoded.map<String, double>((key, value) {
        if (value is! num) {
          throw const FormatException('Invalid cached currency value.');
        }
        return MapEntry(key.toString(), value.toDouble());
      });
    } catch (_) {
      return const {};
    }
  }

  static Future<bool> _isFresh(String key) async {
    final value = await _preferences.getString(key);
    final updatedAt = value == null ? null : DateTime.tryParse(value);
    if (updatedAt == null) return false;
    return DateTime.now().toUtc().difference(updatedAt.toUtc()) <
        cacheDuration;
  }

  static void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message = 'Request failed with status ${response.statusCode}.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {
      // Keep the status-based message when the response is not JSON.
    }
    throw FrankfurterApiException(message);
  }

  static String _normalizeCode(String value) {
    final code = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
      throw ArgumentError.value(value, 'currency', 'Use a 3-letter ISO code.');
    }
    return code;
  }

  static String _ratesKey(String base) => '$_ratesKeyPrefix$base';
  static String _ratesDateKey(String base) => '$_ratesDateKeyPrefix$base';
  static String _ratesUpdatedAtKey(String base) =>
      '$_ratesUpdatedAtKeyPrefix$base';
}
