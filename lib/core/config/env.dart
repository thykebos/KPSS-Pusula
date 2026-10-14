/// Değerler derleme anında `--dart-define-from-file=env.json` ile verilir.
/// `service_role` anahtarı ASLA buraya konmaz; yalnızca anon (public) anahtar kullanılır.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  /// RevenueCat PUBLIC SDK anahtarları (her platform için ayrıdır). Boşsa satın alma devre dışı kalır.
  static const revenueCatAndroidKey = String.fromEnvironment('RC_API_KEY_ANDROID');
  static const revenueCatAppleKey = String.fromEnvironment('RC_API_KEY_APPLE');

  /// Zorunlu olup boş kalan anahtarların listesi.
  static List<String> missingKeys() => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
      ];
}
