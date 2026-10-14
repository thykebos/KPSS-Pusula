import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/network/supabase_client_provider.dart';
import '../../../shared/models/education_level.dart';
import '../domain/appointment_repository.dart';
import '../domain/entities/appointment.dart';
import '../domain/entities/appointment_filter.dart';
import '../domain/entities/appointment_list.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<AppointmentList> fetchAppointments({
    required AppointmentFilter filter,
    int page = 0,
    int limit = 20,
  }) {
    return _guard(() async {
      final res = await _client.rpc(
        'get_appointments',
        params: {
          'p_city': filter.city,
          'p_department': filter.department,
          'p_qualification': filter.qualificationCode,
          'p_kpss': filter.kpss.dbValue,
          'p_query': filter.query,
          'p_my_professions': filter.onlyMyProfessions,
          'p_page': page,
          'p_limit': limit,
        },
      );
      final map = Map<String, dynamic>.from(res as Map);
      final items = (map['items'] as List?)
              ?.map((e) => Appointment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      return AppointmentList(items: items, total: map['total'] as int? ?? 0);
    });
  }

  @override
  Future<AppointmentList> fetchFollowedAppointments({
    int page = 0,
    int limit = 20,
  }) {
    return _guard(() async {
      final res = await _client.rpc(
        'get_followed_appointments',
        params: {'p_page': page, 'p_limit': limit},
      );
      final map = Map<String, dynamic>.from(res as Map);
      final items = (map['items'] as List?)
              ?.map((e) => Appointment.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [];
      return AppointmentList(items: items, total: map['total'] as int? ?? 0);
    });
  }

  @override
  Future<Appointment> fetchDetail(String appointmentId) {
    return _guard(() async {
      final res = await _client.rpc(
        'get_appointment_detail',
        params: {'p_appointment_id': appointmentId},
      );
      return Appointment.fromMap(Map<String, dynamic>.from(res as Map));
    });
  }

  @override
  Future<bool> toggleFollow(String appointmentId) {
    return _guard(() async {
      final res = await _client.rpc(
        'toggle_follow_appointment',
        params: {'p_appointment_id': appointmentId},
      );
      return Map<String, dynamic>.from(res as Map)['is_following'] as bool;
    });
  }
}