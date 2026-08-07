import 'package:supabase_flutter/supabase_flutter.dart';


class SupabaseConfig {
  static late final SupabaseClient client;

  static Future<void> initialize() async {

    const supabaseUrl = 'https://viworhiiejptvsjajgit.supabase.co';
    const supabaseAnonKey = 'sb_secret_h8sVA5s3FrbuQWhF6I-zCQ_h44MYA9S';

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    client = Supabase.instance.client;
  }
}
