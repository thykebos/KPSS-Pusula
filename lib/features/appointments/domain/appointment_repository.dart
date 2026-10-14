import 'entities/appointment.dart';
import 'entities/appointment_filter.dart';
import 'entities/appointment_list.dart';

abstract class AppointmentRepository {
  /// Filtreli ilan listesi (Premium gerekli).
  Future<AppointmentList> fetchAppointments({
    required AppointmentFilter filter,
    int page = 0,
    int limit = 20,
  });

  /// Takip edilen ilanlar (Premium gerekli).
  Future<AppointmentList> fetchFollowedAppointments({
    int page = 0,
    int limit = 20,
  });

  /// Tek ilan detayı.
  Future<Appointment> fetchDetail(String appointmentId);

  /// Takip ekle/kaldır. Yeni durumu döndürür (true = takip ediliyor).
  Future<bool> toggleFollow(String appointmentId);
}