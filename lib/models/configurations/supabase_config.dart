import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static late final SupabaseClient client;

  // deep linking
  static const String authCallbackUrl = 'io.supabase.trek://login-callback/';
  static const String passwordResetCallbackUrl =
      'io.supabase.trek://reset-password-callback/';

  static Future<void> initialize() async {
    const supabaseUrl = 'https://viworhiiejptvsjajgit.supabase.co';
    const supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpd29yaGlpZWpwdHZzamFqZ2l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTQ2NTksImV4cCI6MjEwMTU5MDY1OX0.pKPZa9Ihu4YbpXvl8sBiXcD_fZ7KviDvx8oFUox5_rc';

    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );

    client = Supabase.instance.client;
  }
}
