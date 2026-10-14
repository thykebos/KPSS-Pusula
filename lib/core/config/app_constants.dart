class AppConstants {
  AppConstants._();

  /// Ücretsiz kullanıcının günlük soru limiti. Asıl kural sunucuda (free_daily_limit()) uygulanır;
  /// bu değer yalnızca arayüzde göstermek içindir.
  static const freeDailyLimit = 20;

  /// Ücretsiz kullanıcının seçebileceği ders sayısı.
  static const freeSubjectCount = 2;

  /// Bu genişlikten itibaren masaüstü düzeni (NavigationRail) kullanılır.
  static const desktopBreakpoint = 900.0;
}
