import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'google_places_api_config.dart';

/// Keyless replacement for the Google Places autocomplete calls, built on
/// Photon (https://photon.komoot.io), a free search engine over OpenStreetMap
/// data that is designed for search-as-you-type.
///
/// Used automatically when no `GOOGLE_PLACES_API_KEY` is supplied. It returns
/// plain place names, exactly like [GooglePlacesApiConfig] does, so callers do
/// not need to change.
///
/// Photon's public server is free but fair-use only (no SLA). If the app grows,
/// self-host Photon and change [_host].
class FreePlaceSearchConfig {
  FreePlaceSearchConfig._();

  static const String _host = 'photon.komoot.io';
  static const Map<String, String> _headers = {
    'User-Agent': 'TrekApp/1.0 (Flutter; travel itinerary generator)',
  };

  // Malaysia bounding box: minLon, minLat, maxLon, maxLat.
  static const String _malaysiaBbox = '99.6,0.8,119.3,7.4';

  static const List<String> _hotelTags = [
    'tourism:hotel',
    'tourism:hostel',
    'tourism:guest_house',
    'tourism:motel',
    'tourism:apartment',
  ];
  static const List<String> _airportTags = ['aeroway:aerodrome'];

  /// Small in-memory cache so retyping / backspacing does not re-hit the server.
  static final Map<String, List<String>> _cache = {};

  // ───────────────────────── Public API ─────────────────────────

  static Future<List<String>> getAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    return _searchAcrossDestinations(q, destinations: destinations);
  }

  static Future<List<String>> getHotelAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    final results = await _searchAcrossDestinations(
      query.trim(),
      destinations: destinations,
      osmTags: _hotelTags,
      emptyQueryFallback: 'Hotel',
    );
    return GooglePlacesApiConfig.deduplicateHotels(results).take(6).toList();
  }

  static Future<List<String>> getAirportAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    return _searchAcrossDestinations(
      query.trim(),
      destinations: destinations,
      osmTags: _airportTags,
      emptyQueryFallback: 'Airport',
    );
  }

  // ───────────────────────── Internals ─────────────────────────

  /// Runs one search per selected destination (max 3) and merges the results.
  /// With no destination it searches all of Malaysia.
  static Future<List<String>> _searchAcrossDestinations(
    String query, {
    List<String>? destinations,
    List<String> osmTags = const [],
    String emptyQueryFallback = '',
  }) async {
    final dests = destinations
        ?.map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    // Photon needs a non-empty `q`. For the "show me suggestions" case (empty
    // field) the OSM tag filter does the real work, so search by place name.
    String build(String? dest) {
      final parts = <String>[
        if (query.isNotEmpty) query else if (emptyQueryFallback.isNotEmpty) emptyQueryFallback,
        if (dest != null) dest,
      ];
      return parts.isEmpty ? 'Malaysia' : parts.join(' ');
    }

    if (query.isEmpty && emptyQueryFallback.isEmpty) return [];

    final targets = (dests == null || dests.isEmpty)
        ? <String?>[null]
        : dests.take(3).cast<String?>().toList();

    final lists = await Future.wait(
      targets.map(
        (dest) => _fetch(
          build(dest),
          osmTags: osmTags,
          allowedDestinations: dests,
        ),
      ),
    );

    final seen = <String>{};
    final merged = <String>[];
    for (final list in lists) {
      for (final name in list) {
        if (seen.add(name.toLowerCase())) merged.add(name);
      }
    }
    return merged.take(6).toList();
  }

  static Future<List<String>> _fetch(
    String q, {
    List<String> osmTags = const [],
    List<String>? allowedDestinations,
  }) async {
    final uri = Uri.https(_host, '/api/', {
      'q': q,
      'limit': '15',
      'lang': 'en',
      'bbox': _malaysiaBbox,
      if (osmTags.isNotEmpty) 'osm_tag': osmTags,
    });

    final cacheKey = '$uri|${allowedDestinations?.join(',')}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint('Photon search error: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body);
      final features = (data is Map ? data['features'] : null) as List? ?? [];

      final results = <String>[];
      for (final f in features) {
        final props = (f is Map ? f['properties'] : null) as Map?;
        if (props == null) continue;

        // Photon's bbox also covers parts of SG/TH/BN/ID - keep Malaysia only.
        final country = (props['countrycode'] as String? ?? '').toUpperCase();
        if (country.isNotEmpty && country != 'MY') continue;

        final name = (props['name'] as String? ?? '').trim();
        if (name.isEmpty) continue;
        if (GooglePlacesApiConfig.isParkingText(name)) continue;
        if (name.contains('Bhd') || name.contains('Sdn')) continue;

        if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
          final secondary = [
            props['district'],
            props['city'],
            props['county'],
            props['state'],
          ].whereType<String>().join(', ').toLowerCase();
          if (!GooglePlacesApiConfig.isSecondaryTextInDestinations(
            secondary,
            allowedDestinations,
          )) {
            continue;
          }
        }

        results.add(name);
      }

      final unique = <String>[];
      final seen = <String>{};
      for (final n in results) {
        if (seen.add(n.toLowerCase())) unique.add(n);
      }
      final limited = unique.take(5).toList();
      _cache[cacheKey] = limited;
      return limited;
    } catch (e) {
      debugPrint('Photon search exception: $e');
      return [];
    }
  }
}
