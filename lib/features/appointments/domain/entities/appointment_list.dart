import 'appointment.dart';

/// Sayfalanmış ilan listesi.
class AppointmentList {
  const AppointmentList({required this.items, this.total = 0});

  final List<Appointment> items;
  final int total;

  bool get hasMore => items.length < total;
  bool get isEmpty => items.isEmpty;
}