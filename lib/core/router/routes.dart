class Routes {
  Routes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';

  /// Premium satın alma ekranı (tam ekran).
  static const paywall = '/paywall';

  static const dashboard = '/dashboard';
  static const matik = '/matik';

  /// Soru çözme oturumu (tam ekran). [subjectDb] Subject.dbValue'dur, örn. 'tarih'.
  static String matikSession(String subjectDb) => '$matik/$subjectDb';
  static const appointments = '/appointments';
  static const appointmentsFollowed = '/appointments/followed';
  static String appointmentDetail(String id) => '/appointments/$id';
  static const settings = '/settings';
}
