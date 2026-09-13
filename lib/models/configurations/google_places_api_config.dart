import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thrown when the Google Places API returns REQUEST_DENIED or similar
/// non-recoverable API-level errors (e.g. key not enabled).
class PlacesApiDeniedException implements Exception {
  final String status;
  final String message;
  PlacesApiDeniedException(this.status, this.message);
  @override
  String toString() => 'PlacesApiDeniedException: $status - $message';
}

class GooglePlacesApiConfig {
  // Google Places API Key.
  static const String _apiKey = 'AIzaSyDbfrJOqxQB9-JTTWRxBQKXrpQNFVejeFw';

  /// Check if the API key has been properly configured.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_');

  /// Searches for a place by name/query using the Google Places (New) Text Search API.
  /// Returns the first matching result object, or null if no matches or not configured.
  static Future<Map<String, dynamic>?> searchPlace(String query) async {
    if (!isConfigured) {
      debugPrint(
        'Google Places API search aborted: API key is not configured.',
      );
      return null;
    }

    final String directUrlStr =
        'https://places.googleapis.com/v1/places:searchText';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'places.displayName,places.photos,places.formattedAddress',
    };

    // if (!kIsWeb) {
    //   headers['X-Android-Package'] = 'com.example.trek';
    //   headers['X-Android-Cert'] = '817279A922D846277D95205DE133CEB38DBA0D65';
    // }

    final String body = jsonEncode({"textQuery": query});

    try {
      if (kIsWeb) {
        // Web CORS workaround
        final proxyUrlStr =
            'https://corsproxy.io/?${Uri.encodeComponent(directUrlStr)}';
        final response = await http.post(
          Uri.parse(proxyUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final places = data['places'] as List?;
          if (places != null && places.isNotEmpty) {
            final raw = places.first as Map<String, dynamic>;
            return {
              'name': raw['displayName']?['text'],
              'address': raw['formattedAddress'] as String?,
              'photos': (raw['photos'] as List?)
                  ?.map(
                    (p) => {
                      'photo_reference':
                          p['name'], // New API uses 'name' for photo reference
                    },
                  )
                  .toList(),
            };
          }
        } else {
          debugPrint(
            'Google Places API (Web proxy) Error: ${response.statusCode} - ${response.body}',
          );
          if (response.statusCode == 403) {
            throw PlacesApiDeniedException(
              response.statusCode.toString(),
              response.body,
            );
          }
        }
      } else {
        // Direct request for mobile
        final response = await http.post(
          Uri.parse(directUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final places = data['places'] as List?;
          if (places != null && places.isNotEmpty) {
            final raw = places.first as Map<String, dynamic>;
            return {
              'name': raw['displayName']?['text'],
              'address': raw['formattedAddress'] as String?,
              'photos': (raw['photos'] as List?)
                  ?.map((p) => {'photo_reference': p['name']})
                  .toList(),
            };
          }
        } else {
          try {
            final err = jsonDecode(response.body);
            final status = err["error"]?["status"]?.toString() ?? '';
            final msg = err["error"]?["message"]?.toString() ?? '';
            debugPrint(
              'Google Places API Error: ${response.statusCode} - $status - $msg',
            );
            if (response.statusCode == 403 ||
                status == 'PERMISSION_DENIED' ||
                status == 'REQUEST_DENIED') {
              throw PlacesApiDeniedException(status, msg);
            }
          } catch (e) {
            if (e is PlacesApiDeniedException) rethrow;
            debugPrint(
              'Google Places API Error: ${response.statusCode} - ${response.body}',
            );
            if (response.statusCode == 403) {
              throw PlacesApiDeniedException(
                response.statusCode.toString(),
                response.body,
              );
            }
          }
        }
      }
    } catch (e) {
      if (e is PlacesApiDeniedException) rethrow;
      debugPrint('Google Places API Exception: $e');
    }
    return null;
  }

  static bool _isSecondaryTextInDestinations(
    String secondaryText,
    List<String> destinations,
  ) {
    if (secondaryText.isEmpty) return true;
    final secLower = secondaryText.toLowerCase();

    for (final dest in destinations) {
      final dLower = dest.toLowerCase().trim();
      if (secLower.contains(dLower)) return true;
      if (dLower == 'penang' &&
          (secLower.contains('pulau pinang') ||
              secLower.contains('george town') ||
              secLower.contains('butterworth') ||
              secLower.contains('batu ferringhi') ||
              secLower.contains('bayan lepas'))) {
        return true;
      }
      if ((dLower == 'melaka' || dLower == 'malacca') &&
          (secLower.contains('melaka') || secLower.contains('malacca'))) {
        return true;
      }
      if (dLower == 'kuala lumpur' &&
          (secLower.contains('kuala lumpur') || secLower.contains('kl'))) {
        return true;
      }
    }

    final otherStates = [
      'kuala lumpur',
      'penang',
      'pulau pinang',
      'selangor',
      'johor',
      'perak',
      'kedah',
      'pahang',
      'sabah',
      'sarawak',
      'melaka',
      'malacca',
      'terengganu',
      'kelantan',
      'negeri sembilan',
      'perlis',
      'putrajaya',
      'labuan',
    ];
    for (final state in otherStates) {
      if (secLower.contains(state)) {
        final matchesAnyDest = destinations.any(
          (d) =>
              d.toLowerCase().contains(state) ||
              state.contains(d.toLowerCase()),
        );
        if (!matchesAnyDest) return false;
      }
    }

    return true;
  }

  /// Searches Google Places (New) Autocomplete for a query and returns a list of suggested place names.
  /// When [destinations] is provided, suggestions are strictly filtered to the selected destinations.
  static Future<List<String>> getAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    if (!isConfigured) return [];
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final validDestinations = destinations
        ?.map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    if (validDestinations == null || validDestinations.isEmpty) {
      return await _fetchAutocomplete(trimmedQuery);
    }

    // Query for each selected destination strictly
    final targetDestinations = validDestinations.take(3).toList();
    final futures = targetDestinations.map(
      (dest) => _fetchAutocomplete('$trimmedQuery, $dest', validDestinations),
    );

    final resultsList = await Future.wait(futures);
    final Set<String> combined = {};
    for (final list in resultsList) {
      for (final item in list) {
        if (!isParkingText(item)) {
          combined.add(item);
        }
      }
    }

    return combined.take(6).toList();
  }

  /// Extracts place suggestion names excluding any parking facilities or parking lots.
  static List<String> _extractNonParkingSuggestions(
    List suggestions, [
    List<String>? allowedDestinations,
  ]) {
    final List<String> results = [];
    for (final s in suggestions) {
      final placePrediction = s['placePrediction'];
      if (placePrediction == null) continue;

      if (_isParkingPrediction(placePrediction)) continue;

      final structured = placePrediction['structuredFormat'];
      final secondaryText =
          (structured?['secondaryText']?['text'] as String? ?? '').toLowerCase();

      if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
        if (!_isSecondaryTextInDestinations(secondaryText, allowedDestinations)) {
          continue;
        }
      }

      final mainText = structured?['mainText']?['text'] as String?;
      final fullText = placePrediction['text']?['text'] as String?;
      final text = mainText?.trim() ?? fullText?.trim();
      if (text != null && text.isNotEmpty && !isParkingText(text)) {
        results.add(text);
      }
    }
    return results.take(5).toList();
  }

  /// Determines if a place prediction represents a parking facility based on types or naming.
  static bool _isParkingPrediction(dynamic placePrediction) {
    if (placePrediction is! Map) return false;

    // 1. Check Google Places types
    final types = (placePrediction['types'] as List?)
            ?.map((t) => t.toString().toLowerCase())
            .toList() ??
        const [];
    const parkingTypes = {
      'parking',
      'parking_lot',
      'parking_garage',
      'valet_parking',
    };
    if (types.any((t) => parkingTypes.contains(t) || t.contains('parking'))) {
      return true;
    }

    // 2. Check mainText and fullText
    final structured = placePrediction['structuredFormat'];
    final mainText = structured?['mainText']?['text'] as String?;
    final fullText = placePrediction['text']?['text'] as String?;

    return isParkingText(mainText) || isParkingText(fullText);
  }

  /// Checks if a string indicates a parking location (car park, parking lot, etc.)
  static bool isParkingText(String? text) {
    if (text == null || text.trim().isEmpty) return false;
    final lower = text.trim().toLowerCase();

    final parkingPattern = RegExp(
      r'(\bparking\b|\bcar\s*parks?\b|\bmotorcycle\s*parks?\b|\bparkir\b|\b(tempat|tapak)\s+letak\s+kereta\b|\bvalet\s+parking\b|停车场|泊车场|停车楼)',
      caseSensitive: false,
    );
    return parkingPattern.hasMatch(lower);
  }

  static Future<List<String>> _fetchAutocomplete(
    String inputQuery, [
    List<String>? allowedDestinations,
  ]) async {
    final String directUrlStr =
        'https://places.googleapis.com/v1/places:autocomplete';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
    };

    final String body = jsonEncode({
      "input": inputQuery,
      "includedRegionCodes": [
        "my",
      ], // Strictly restrict search results to Malaysia
    });

    try {
      if (kIsWeb) {
        final proxyUrlStr =
            'https://corsproxy.io/?${Uri.encodeComponent(directUrlStr)}';
        final response = await http.post(
          Uri.parse(proxyUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            return _extractNonParkingSuggestions(
              suggestions,
              allowedDestinations,
            );
          }
        } else {
          debugPrint(
            'Google Places Autocomplete (Web proxy) Error: ${response.statusCode} - ${response.body}',
          );
        }
      } else {
        final response = await http.post(
          Uri.parse(directUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            return _extractNonParkingSuggestions(
              suggestions,
              allowedDestinations,
            );
          }
        } else {
          try {
            final err = jsonDecode(response.body);
            debugPrint(
              'Google Places Autocomplete Error: ${response.statusCode} - ${err["error"]["status"]} - ${err["error"]["message"]}',
            );
          } catch (_) {
            debugPrint(
              'Google Places Autocomplete HTTP Error: ${response.statusCode} - ${response.body}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Google Places Autocomplete Exception: $e');
    }
    return [];
  }

  /// Normalizes a hotel name for deduplication comparison (trims whitespace, lowercases, collapses internal whitespace, removes trailing location/country suffix).
  static String normalizeHotelName(String name) {
    var key = name.trim().toLowerCase();
    key = key.replaceAll(RegExp(r',\s*malaysia$', caseSensitive: false), '');
    key = key.replaceAll(RegExp(r'\s+'), ' ');
    return key.trim();
  }

  /// Deduplicates a collection of hotel names while preserving original order and formatting of first occurrences.
  static List<String> deduplicateHotels(Iterable<String> rawSuggestions) {
    final seen = <String>{};
    final unique = <String>[];
    for (final raw in rawSuggestions) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final normalizedKey = normalizeHotelName(trimmed);
      if (normalizedKey.isNotEmpty && seen.add(normalizedKey)) {
        unique.add(trimmed);
      }
    }
    return unique;
  }

  /// Searches Google Places (New) Autocomplete specifically for hotels/accommodations, biased or filtered by [destinations].
  static Future<List<String>> getHotelAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    if (!isConfigured) return [];
    final trimmedQuery = query.trim();

    final validDestinations = destinations
        ?.map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    // 1. If query is empty: search Google Places API for hotels in each selected destination
    if (trimmedQuery.isEmpty) {
      if (validDestinations == null || validDestinations.isEmpty) {
        final results = await _fetchHotelAutocomplete('Hotel, Malaysia');
        return deduplicateHotels(results).take(6).toList();
      }

      final targetDestinations = validDestinations.take(3).toList();
      final futures = targetDestinations.map(
        (dest) => _fetchHotelAutocomplete('Hotel, $dest'),
      );
      final resultsList = await Future.wait(futures);
      final List<String> combined = [];
      for (final list in resultsList) {
        combined.addAll(list);
      }
      return deduplicateHotels(combined).take(6).toList();
    }

    // 2. If user typed a query:
    if (validDestinations == null || validDestinations.isEmpty) {
      final results = await _fetchHotelAutocomplete(trimmedQuery);
      if (results.isNotEmpty) return deduplicateHotels(results).take(6).toList();
      final fallback = await _fetchHotelAutocomplete('$trimmedQuery Hotel');
      return deduplicateHotels(fallback).take(6).toList();
    }

    // If query already contains any destination name
    final lowerQuery = trimmedQuery.toLowerCase();
    final alreadyIncludesDestination = validDestinations.any(
      (dest) => lowerQuery.contains(dest.toLowerCase()),
    );

    if (alreadyIncludesDestination) {
      final results = await _fetchHotelAutocomplete(
        trimmedQuery,
        validDestinations,
      );
      if (results.isNotEmpty) return deduplicateHotels(results).take(6).toList();
      final fallback = await _fetchHotelAutocomplete(
        '$trimmedQuery Hotel',
        validDestinations,
      );
      return deduplicateHotels(fallback).take(6).toList();
    }

    // Query for each selected destination in parallel
    final targetDestinations = validDestinations.take(3).toList();
    final futures = targetDestinations.map(
      (dest) => _fetchHotelAutocomplete('$trimmedQuery, $dest', validDestinations),
    );
    final resultsList = await Future.wait(futures);
    final List<String> combined = [];
    for (final list in resultsList) {
      combined.addAll(list);
    }

    if (deduplicateHotels(combined).length < 2) {
      final fallbackFutures = targetDestinations.map(
        (dest) => _fetchHotelAutocomplete(
          lowerQuery.contains('hotel')
              ? '$trimmedQuery, $dest'
              : '$trimmedQuery Hotel, $dest',
          validDestinations,
        ),
      );
      final fallbackResults = await Future.wait(fallbackFutures);
      for (final list in fallbackResults) {
        combined.addAll(list);
      }
    }

    return deduplicateHotels(combined).take(6).toList();
  }

  static Future<List<String>> _fetchHotelAutocomplete(
    String inputQuery, [
    List<String>? allowedDestinations,
  ]) async {
    final String directUrlStr =
        'https://places.googleapis.com/v1/places:autocomplete';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
    };

    final String body = jsonEncode({
      "input": inputQuery,
      "includedPrimaryTypes": ["lodging"],
      "includedRegionCodes": ["my"],
    });

    try {
      if (kIsWeb) {
        final proxyUrlStr =
            'https://corsproxy.io/?${Uri.encodeComponent(directUrlStr)}';
        final response = await http.post(
          Uri.parse(proxyUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            final List<String> parsedList = [];
            for (final s in suggestions) {
              final structured = s['placePrediction']?['structuredFormat'];
              final secondaryText =
                  (structured?['secondaryText']?['text'] as String? ?? '')
                      .toLowerCase();

              if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
                if (!_isSecondaryTextInDestinations(
                  secondaryText,
                  allowedDestinations,
                )) {
                  continue;
                }
              }

              final mainText = structured?['mainText']?['text'] as String?;
              final fullText = s['placePrediction']?['text']?['text'] as String?;
              final text = mainText?.trim() ?? fullText?.trim();
              if (text != null && text.isNotEmpty) {
                parsedList.add(text);
              }
            }
            return deduplicateHotels(parsedList).take(5).toList();
          }
        }
      } else {
        final response = await http.post(
          Uri.parse(directUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            final List<String> parsedList = [];
            for (final s in suggestions) {
              final structured = s['placePrediction']?['structuredFormat'];
              final secondaryText =
                  (structured?['secondaryText']?['text'] as String? ?? '')
                      .toLowerCase();

              if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
                if (!_isSecondaryTextInDestinations(
                  secondaryText,
                  allowedDestinations,
                )) {
                  continue;
                }
              }

              final mainText = structured?['mainText']?['text'] as String?;
              final fullText = s['placePrediction']?['text']?['text'] as String?;
              final text = mainText?.trim() ?? fullText?.trim();
              if (text != null && text.isNotEmpty) {
                parsedList.add(text);
              }
            }
            return deduplicateHotels(parsedList).take(5).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Google Places Hotel Autocomplete Error: $e');
    }
    return [];
  }

  /// Searches Google Places (New) Autocomplete specifically for airports, biased or filtered by [destinations].
  static Future<List<String>> getAirportAutocompleteSuggestions(
    String query, {
    List<String>? destinations,
  }) async {
    if (!isConfigured) return [];
    final trimmedQuery = query.trim();

    final validDestinations = destinations
        ?.map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    // 1. If query is empty: search Google Places API for each destination's airports
    if (trimmedQuery.isEmpty) {
      if (validDestinations == null || validDestinations.isEmpty) {
        return await _fetchAirportAutocomplete('Malaysia Airport');
      }

      final targetDestinations = validDestinations.take(3).toList();
      final futures = targetDestinations.map(
        (dest) => _fetchAirportAutocomplete('$dest Airport', validDestinations),
      );
      final resultsList = await Future.wait(futures);
      final Set<String> combined = {};
      for (final list in resultsList) {
        combined.addAll(list);
      }
      return combined.take(6).toList();
    }

    // 2. If user typed a query:
    if (validDestinations == null || validDestinations.isEmpty) {
      final results = await _fetchAirportAutocomplete(
        trimmedQuery.toLowerCase().contains('airport')
            ? trimmedQuery
            : '$trimmedQuery Airport',
      );
      if (results.isNotEmpty) return results;
      return await _fetchAirportAutocomplete(trimmedQuery);
    }

    // If query already contains any destination name
    final lowerQuery = trimmedQuery.toLowerCase();
    final alreadyIncludesDestination = validDestinations.any(
      (dest) => lowerQuery.contains(dest.toLowerCase()),
    );

    if (alreadyIncludesDestination) {
      final results = await _fetchAirportAutocomplete(
        lowerQuery.contains('airport') ? trimmedQuery : '$trimmedQuery Airport',
        validDestinations,
      );
      if (results.isNotEmpty) return results;
      return await _fetchAirportAutocomplete(trimmedQuery, validDestinations);
    }

    // Query for each selected destination in parallel
    final targetDestinations = validDestinations.take(3).toList();
    final futures = targetDestinations.map(
      (dest) => _fetchAirportAutocomplete('$trimmedQuery, $dest', validDestinations),
    );
    final resultsList = await Future.wait(futures);
    final Set<String> combined = {};
    for (final list in resultsList) {
      combined.addAll(list);
    }

    if (combined.length < 2) {
      final fallbackFutures = targetDestinations.map(
        (dest) => _fetchAirportAutocomplete(
          lowerQuery.contains('airport')
              ? '$trimmedQuery, $dest'
              : '$trimmedQuery Airport, $dest',
          validDestinations,
        ),
      );
      final fallbackResults = await Future.wait(fallbackFutures);
      for (final list in fallbackResults) {
        combined.addAll(list);
      }
    }

    return combined.take(6).toList();
  }

  static Future<List<String>> _fetchAirportAutocomplete(
    String inputQuery, [
    List<String>? allowedDestinations,
  ]) async {
    final String directUrlStr =
        'https://places.googleapis.com/v1/places:autocomplete';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
    };

    final String body = jsonEncode({
      "input": inputQuery,
      "includedPrimaryTypes": ["airport"],
      "includedRegionCodes": ["my"],
    });

    try {
      if (kIsWeb) {
        final proxyUrlStr =
            'https://corsproxy.io/?${Uri.encodeComponent(directUrlStr)}';
        final response = await http.post(
          Uri.parse(proxyUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            final List<String> parsedList = [];
            for (final s in suggestions) {
              final structured = s['placePrediction']?['structuredFormat'];
              final secondaryText =
                  (structured?['secondaryText']?['text'] as String? ?? '')
                      .toLowerCase();

              if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
                if (!_isSecondaryTextInDestinations(
                  secondaryText,
                  allowedDestinations,
                )) {
                  continue;
                }
              }

              final mainText = structured?['mainText']?['text'] as String?;
              final fullText = s['placePrediction']?['text']?['text'] as String?;
              final text = mainText ?? fullText;
              if (text != null &&
                  !text.contains('Bhd') &&
                  !text.contains('Sdn')) {
                parsedList.add(text);
              }
            }
            return parsedList.take(5).toList();
          }
        }
      } else {
        final response = await http.post(
          Uri.parse(directUrlStr),
          headers: headers,
          body: body,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final suggestions = data['suggestions'] as List?;
          if (suggestions != null) {
            final List<String> parsedList = [];
            for (final s in suggestions) {
              final structured = s['placePrediction']?['structuredFormat'];
              final secondaryText =
                  (structured?['secondaryText']?['text'] as String? ?? '')
                      .toLowerCase();

              if (allowedDestinations != null && allowedDestinations.isNotEmpty) {
                if (!_isSecondaryTextInDestinations(
                  secondaryText,
                  allowedDestinations,
                )) {
                  continue;
                }
              }

              final mainText = structured?['mainText']?['text'] as String?;
              final fullText = s['placePrediction']?['text']?['text'] as String?;
              final text = mainText ?? fullText;
              if (text != null &&
                  !text.contains('Bhd') &&
                  !text.contains('Sdn')) {
                parsedList.add(text);
              }
            }
            return parsedList.take(5).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Google Places Airport Autocomplete Error: $e');
    }
    return [];
  }

  /// Builds and returns the HTTP URL for retrieving a Place Photo.
  /// Note that this URL can be directly passed to Image.network().
  /// For the New Places API, `photoReference` is the `name` field from the photo object (e.g. `places/XYZ/photos/ABC`).
  static String getPhotoUrl(String photoReference, {int maxWidth = 600}) {
    if (!isConfigured) return '';

    // In New API, photoReference includes 'places/.../photos/...'
    final directUrl =
        'https://places.googleapis.com/v1/$photoReference/media?maxHeightPx=$maxWidth&maxWidthPx=$maxWidth&key=$_apiKey';

    // if (kIsWeb) {
    //   // Use CORS proxy for images on web to avoid Canvas/CORS paint exceptions.
    //   return 'https://corsproxy.io/?${Uri.encodeComponent(directUrl)}';
    // }
    return directUrl;
  }

  /// Searches for a place by name and returns the direct Google Places photo URL
  /// for the first photo available, or null if not found.
  static Future<String?> searchPlacePhotoUrl(String placeName) async {
    final placeDetails = await searchPlace(placeName);
    if (placeDetails == null) return null;

    final photos = placeDetails['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final firstPhoto = photos.first as Map<String, dynamic>;
      // We mapped the New API 'name' to 'photo_reference' for backwards compatibility
      final photoReference = firstPhoto['photo_reference'] as String?;
      if (photoReference != null && photoReference.isNotEmpty) {
        return getPhotoUrl(photoReference);
      }
    }
    return null;
  }
}
