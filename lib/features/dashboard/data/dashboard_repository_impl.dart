import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../domain/dashboard_repository.dart';
import '../domain/entities/appointment_summary.dart';
import '../domain/entities/dashboard_stats.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<DashboardStats> fetchStats() {
    return _guard(() async {
      final res = await _client.rpc('get_dashboard_stats');
      return DashboardStats.fromMap(Map<String, dynamic>.from(res as Map));
    });
  }

  @override
  Future<List<AppointmentSummary>> fetchLatestAppointments({int limit = 3}) {
    return _guard(() async {
      final rows = await _client
          .from('appointments')
          .select('id, title, institution, city, application_end')
          .order('published_at', ascending: false)
          .limit(limit);
      return rows
          .map((row) => AppointmentSummary.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    });
  }
}
