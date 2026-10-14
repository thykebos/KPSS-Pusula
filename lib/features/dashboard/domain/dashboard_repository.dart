import 'entities/appointment_summary.dart';
import 'entities/dashboard_stats.dart';

abstract class DashboardRepository {
  /// Günlük istatistik, Premium durumu ve yaklaşan sınav (tek RPC çağrısı).
  Future<DashboardStats> fetchStats();

  /// En yeni ilanlar. Yalnızca Premium kullanıcı görebilir (sunucu RLS'i uygular);
  /// ücretsiz kullanıcıda sunucu boş liste döndürür.
  Future<List<AppointmentSummary>> fetchLatestAppointments({int limit = 3});
}
