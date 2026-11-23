import 'package:flutter/foundation.dart';

/// Single place where build-time secrets are read.
///
/// Values are injected at build/run time with `--dart-define` (or
/// `--dart-define-from-file=env.json`), so they never live in source control.
/// See `env.example.json` for the expected keys.
///
/// Note: `String.fromEnvironment` MUST be called with a literal key inside a
/// `const` expression, which is why each key is spelled out below.
class AppSecrets {
  AppSecrets._();

  /// OPTIONAL, local development only. Leave it out (the normal case) and the
  /// app calls Gemini through the `gemini-proxy` Supabase Edge Function, whose
  /// secret key lives on the server. Anything passed here is compiled into the
  /// app, so never ship a build that was made with this set.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String googlePlacesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
  );

  static const String openRouteServiceApiKey = String.fromEnvironment(
    'OPENROUTESERVICE_API_KEY',
  );

  /// Logs (debug builds only) what was not supplied.
  ///
  /// No key is required. Without GEMINI_API_KEY, Gemini goes through the
  /// Supabase Edge Function. The Google Places / OpenRouteService keys are
  /// optional paid add-ons; without them the app uses free keyless services:
  ///  - no GOOGLE_PLACES_API_KEY -> Photon (OpenStreetMap) autocomplete and
  ///    Wikipedia/Wikimedia images
  ///  - no OPENROUTESERVICE_API_KEY -> OSRM public routing
  static void warnAboutMissingKeys() {
    if (!kDebugMode) return;
    if (geminiApiKey.isEmpty) {
      debugPrint('AppSecrets: no local Gemini key - using the gemini-proxy Edge Function.');
    } else {
      debugPrint('AppSecrets: DEV MODE - calling Gemini directly with a key compiled into this build.');
    }
    if (googlePlacesApiKey.isEmpty) {
      debugPrint('AppSecrets: no Google Places key - using free Photon/Wikipedia.');
    }
    if (openRouteServiceApiKey.isEmpty) {
      debugPrint('AppSecrets: no OpenRouteService key - using free OSRM routing.');
    }
  }
}
