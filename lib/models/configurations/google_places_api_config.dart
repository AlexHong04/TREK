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
  static const String _apiKey = 'AIzaSyAro7bHvmh72uWZCKqLkl4-tizXJHiO_k0';

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
      'X-Goog-FieldMask': 'places.displayName,places.photos',
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

  /// Searches Google Places (New) Autocomplete for a query and returns a list of suggested place names.
  static Future<List<String>> getAutocompleteSuggestions(String query) async {
    if (!isConfigured) return [];

    final String directUrlStr =
        'https://places.googleapis.com/v1/places:autocomplete';

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
    };
    // if (!kIsWeb) {
    //   headers['X-Android-Package'] = 'com.example.trek';
    //   headers['X-Android-Cert'] = '817279A922D846277D95205DE133CEB38DBA0D65';
    // }

    final String body = jsonEncode({
      "input": query,
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
            return suggestions
                .map((s) {
                  final mainText =
                      s['placePrediction']?['structuredFormat']?['mainText']?['text']
                          as String?;
                  final fullText =
                      s['placePrediction']?['text']?['text'] as String?;
                  return mainText ?? fullText;
                })
                .where((text) => text != null)
                .cast<String>()
                .take(5)
                .toList();
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
            return suggestions
                .map((s) {
                  final mainText =
                      s['placePrediction']?['structuredFormat']?['mainText']?['text']
                          as String?;
                  final fullText =
                      s['placePrediction']?['text']?['text'] as String?;
                  return mainText ?? fullText;
                })
                .where((text) => text != null)
                .cast<String>()
                .take(5)
                .toList();
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
