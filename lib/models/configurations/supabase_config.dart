import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static late final SupabaseClient client;

  // deep linking
  static const String authCallbackUrl = 'io.supabase.trek://login-callback/';
  static const String passwordResetCallbackUrl =
      'io.supabase.trek://reset-password-callback/';

  static const String url = 'https://viworhiiejptvsjajgit.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpd29yaGlpZWpwdHZzamFqZ2l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTQ2NTksImV4cCI6MjEwMTU5MDY1OX0.pKPZa9Ihu4YbpXvl8sBiXcD_fZ7KviDvx8oFUox5_rc';

  /// Base URL of this project's Edge Functions.
  static const String functionsUrl = '$url/functions/v1';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
    );

    client = Supabase.instance.client;
  }
}
