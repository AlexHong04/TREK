/// Shared, app-wide SharedPreferences keys.
class PreferenceKeys {
  PreferenceKeys._();

  /// Set right after a successful registration. While it is `true`, the Home
  /// screen shows the one-off user guide and clears the flag once the tourist
  /// finishes (or skips) it - so the guide appears exactly once, on their very
  /// first login after signing up.
  static const String userGuidePending = 'userGuidePending';
}
