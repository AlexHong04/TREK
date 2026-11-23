import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_secrets.dart';

class OpenRouteServiceException implements Exception {
  final String message;
  const OpenRouteServiceException(this.message);

  @override
  String toString() => 'OpenRouteServiceException: $message';
}

/// Configuration and network client for OpenRouteService (ORS) API.
/// Used to calculate realistic road distances and driving/bus durations across Malaysia.
class OpenRouteServiceApiConfig {
  OpenRouteServiceApiConfig._();

  static const String baseUrl =
      'https://api.openrouteservice.org/v2/directions/driving-car';
  static const String _storageApiKey = 'trek.openrouteservice.api_key';

  /// Default key injected at build time (see AppSecrets). If empty, a key saved
  /// through [setApiKey] is used instead.
  static String _currentApiKey = AppSecrets.openRouteServiceApiKey;

  /// Set or update the API Key in memory and persistence.
  static Future<void> setApiKey(String key) async {
    _currentApiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageApiKey, _currentApiKey);
    } catch (_) {}
  }

  /// Get the active API Key.
  static Future<String> getApiKey() async {
    if (_currentApiKey.isNotEmpty) return _currentApiKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_storageApiKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _currentApiKey = saved.trim();
      }
    } catch (_) {}
    return _currentApiKey;
  }

  /// Calculates road travel duration (in minutes) and distance (in km) between two coordinates.
  /// [startLat], [startLng] : Origin coordinates.
  /// [endLat], [endLng]     : Destination coordinates.
  /// Returns a map: `{'durationMinutes': int, 'distanceKm': double}`.
  static Future<Map<String, dynamic>> calculateDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    bool isBus = true,
  }) async {
    final apiKey = await getApiKey();

    // No ORS key: use the free, keyless OSRM public server instead.
    final ({double durationSeconds, double distanceMeters}) route =
        apiKey.isEmpty
        ? await _fetchOsrmRoute(startLat, startLng, endLat, endLng)
        : await _fetchOrsRoute(apiKey, startLat, startLng, endLat, endLng);

    final double durationSeconds = route.durationSeconds;
    final double distanceMeters = route.distanceMeters;

    int durationMinutes = (durationSeconds / 60.0).round();

    // For express buses in Malaysia:
    // 1. Buses have a highway speed limit (90 km/h) compared to passenger cars (110 km/h).
    // 2. Add ~20-25 mins buffer for toll booths, passenger boarding, and highway R&R rest stops on intercity trips.
    if (isBus) {
      final double busFactor =
          1.12; // ~12% slower than car due to 90 km/h governor
      durationMinutes = (durationMinutes * busFactor).round();
      if (distanceMeters > 50000) {
        // Intercity trips (>50km) include an R&R or toll buffer
        durationMinutes += 20;
      }
    }

    return {
      'durationMinutes': durationMinutes,
      'distanceKm': (distanceMeters / 1000.0),
      'rawSeconds': durationSeconds,
    };
  }

  static Future<({double durationSeconds, double distanceMeters})>
  _fetchOrsRoute(
    String apiKey,
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    // OpenRouteService expects longitude,latitude
    final uri = Uri.parse(
      '$baseUrl?api_key=$apiKey&start=$startLng,$startLat&end=$endLng,$endLat',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw OpenRouteServiceException(
        'OpenRouteService request failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> || !data.containsKey('features')) {
      throw const OpenRouteServiceException(
        'Invalid response format from OpenRouteService.',
      );
    }

    final features = data['features'] as List<dynamic>;
    if (features.isEmpty) {
      throw const OpenRouteServiceException(
        'No route found between the given coordinates.',
      );
    }

    final summary = features[0]['properties']?['summary'];
    if (summary == null) {
      throw const OpenRouteServiceException(
        'Summary data not found in route response.',
      );
    }

    return (
      durationSeconds: (summary['duration'] as num).toDouble(),
      distanceMeters: (summary['distance'] as num).toDouble(),
    );
  }

  /// Free, keyless routing via the public OSRM demo server (fair use only; it
  /// is fine for the handful of fixed bus-hub lookups this app makes).
  static Future<({double durationSeconds, double distanceMeters})>
  _fetchOsrmRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    // OSRM also expects longitude,latitude.
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLng,$startLat;$endLng,$endLat?overview=false',
    );

    final response = await http
        .get(
          uri,
          headers: const {
            'User-Agent': 'TrekApp/1.0 (Flutter; travel itinerary generator)',
          },
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw OpenRouteServiceException(
        'OSRM request failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final routes = (data is Map<String, dynamic> && data['code'] == 'Ok')
        ? data['routes'] as List<dynamic>?
        : null;
    if (routes == null || routes.isEmpty) {
      throw const OpenRouteServiceException(
        'No route found between the given coordinates.',
      );
    }

    return (
      durationSeconds: (routes[0]['duration'] as num).toDouble(),
      distanceMeters: (routes[0]['distance'] as num).toDouble(),
    );
  }
}
