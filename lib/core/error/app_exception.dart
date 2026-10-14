/// Arayüze gösterilebilir, Türkçe mesaj taşıyan uygulama hatası.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;

  /// Sunucudan gelen makine-okunur kod (örn. 'daily_limit_reached').
  final String? code;

  @override
  String toString() => message;
}
