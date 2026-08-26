import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GooglePlacesApiConfig {
  // Google Places API Key.
  // Developers should replace this placeholder with their own valid Google Maps Platform API Key.
  static const String _apiKey = 'AIzaSyAro7bHvmh72uWZCKqLkl4-tizXJHiO_k0';

  /// Check if the API key has been properly configured.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && !_apiKey.startsWith('YOUR_');

  /// Searches for a place by name/query using the Google Places Text Search API.
  /// Returns the first matching result object, or null if no matches or not configured.
  static Future<Map<String, dynamic>?> searchPlace(String query) async {
    if (!isConfigured) {
      debugPrint(
        'Google Places API search aborted: API key is not configured.',
      );
      return null;
    }

    final encodedQuery = Uri.encodeComponent(query);
    final String directUrlStr =
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$_apiKey';

    final Map<String, String> headers = {};
    if (!kIsWeb) {
      headers['X-Android-Package'] = 'com.example.trek';
      headers['X-Android-Cert'] = '817279A922D846277D95205DE133CEB38DBA0D65';
    }

    if (kIsWeb) {
      // Web CORS workaround: try corsproxy.io first (generally faster/more stable),
      // and fall back to api.allorigins.win if it fails.
      final proxyUrls = [
        'https://corsproxy.io/?${Uri.encodeComponent(directUrlStr)}',
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(directUrlStr)}',
      ];

      for (final proxyUrlStr in proxyUrls) {
        try {
          final response = await http.get(
            Uri.parse(proxyUrlStr),
            headers: headers,
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final results = data['results'] as List?;
            if (results != null && results.isNotEmpty) {
              return results.first as Map<String, dynamic>;
            }
            return null;
          } else {
            debugPrint(
              'CORS Proxy error ($proxyUrlStr): ${response.statusCode}',
            );
          }
        } catch (e) {
          debugPrint('CORS Proxy Exception ($proxyUrlStr): $e');
        }
      }
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(directUrlStr),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          return results.first as Map<String, dynamic>;
        }
      } else {
        debugPrint(
          'Google Places API Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Google Places API Exception: $e');
    }
    return null;
  }

  /// Builds and returns the HTTP URL for retrieving a Place Photo.
  /// Note that this URL can be directly passed to Image.network().
  static String getPhotoUrl(String photoReference, {int maxWidth = 600}) {
    if (!isConfigured) return '';
    final directUrl =
        'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&photo_reference=$photoReference&key=$_apiKey';
    if (kIsWeb) {
      // Use CORS proxy for images on web to avoid Canvas/CORS paint exceptions.
      // corsproxy.io is faster and more reliable than api.allorigins.win.
      return 'https://corsproxy.io/?${Uri.encodeComponent(directUrl)}';
    }
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
      final photoReference = firstPhoto['photo_reference'] as String?;
      if (photoReference != null && photoReference.isNotEmpty) {
        return getPhotoUrl(photoReference);
      }
    }
    return null;
  }
}
