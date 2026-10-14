import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/dashboard_repository_impl.dart';
import '../../domain/dashboard_repository.dart';
import '../../domain/entities/appointment_summary.dart';
import '../../domain/entities/dashboard_stats.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.watch(supabaseProvider)),
);

/// Ana ekran verisi. Matik oturumundan dönünce yenilenir (bkz. subject_select_screen).
final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(dashboardRepositoryProvider).fetchStats();
});

/// Son ilanlar. Ücretsiz kullanıcıda sunucuya hiç sorgu atılmaz.
final latestAppointmentsProvider =
    FutureProvider.autoDispose<List<AppointmentSummary>>((ref) async {
  final stats = await ref.watch(dashboardStatsProvider.future);
  if (!stats.isPremium) return const [];
  return ref.watch(dashboardRepositoryProvider).fetchLatestAppointments(limit: 3);
});
