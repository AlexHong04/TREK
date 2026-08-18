import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static late final SupabaseClient client;

  static Future<void> initialize() async {
    const supabaseUrl = 'https://viworhiiejptvsjajgit.supabase.co';
    const supabaseAnonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZpd29yaGlpZWpwdHZzamFqZ2l0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTQ2NTksImV4cCI6MjEwMTU5MDY1OX0.pKPZa9Ihu4YbpXvl8sBiXcD_fZ7KviDvx8oFUox5_rc';

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    client = Supabase.instance.client;
  }
}
