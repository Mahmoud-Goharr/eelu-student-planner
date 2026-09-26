class SupabaseConstants {
  const SupabaseConstants._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xtinkinynygfhhwieips.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_cnTzUkWtQsA2d4vXo4l7lA_IG_GFkV9',
  );

  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '914739351348-1g8tdfivkf5dn0ipplbljio27m21n1f2.apps.googleusercontent.com',
  );
}
