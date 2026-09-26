import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  GoTrueClient get auth => client.auth;
}
