import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/daily_stats_card.dart';
import '../widgets/exam_countdown_card.dart';
import '../widgets/latest_appointments_strip.dart';

/// Ana ekran: sınav sayacı, günlük istatistik ve (Premium'a özel) son ilanlar.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardStatsProvider);
    try {
      await ref.read(dashboardStatsProvider.future);
    } catch (_) {
      // Hata, ekranın hata görünümünde gösterilir; yenileme göstergesi yine de kapanmalı.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      body: statsAsync.when(
        // Yenilemede içerik yerinde kalsın; ekran spinner'a dönüp kaydırmayı bozmasın.
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Ana sayfa yüklenemedi.',
          onRetry: () => ref.invalidate(dashboardStatsProvider),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _Content(
            stats: stats,
            onPremiumTap: () => context.push(Routes.paywall),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.stats, required this.onPremiumTap});

  final DashboardStats stats;
  final VoidCallback onPremiumTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final name = profile?.fullName?.trim().split(' ').first;
    final appointments = ref.watch(latestAppointmentsProvider);

    final countdown = ExamCountdownCard(exam: stats.nextExam);
    final daily = DailyStatsCard(
      stats: stats,
      onStart: () => context.go(Routes.matik),
    );
    final latest = LatestAppointmentsStrip(
      isPremium: stats.isPremium,
      appointments: appointments,
      onSeeAll: () => context.go(Routes.appointments),
      onUpgrade: onPremiumTap,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return ListView(
              // Kısa içerikte de aşağı çekerek yenileme çalışsın.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  (name == null || name.isEmpty) ? 'Merhaba!' : 'Merhaba $name!',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Seviyen: ${profile?.educationLevel.label ?? '-'}'),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: countdown),
                      const SizedBox(width: 16),
                      Expanded(child: daily),
                    ],
                  )
                else ...[
                  countdown,
                  const SizedBox(height: 16),
                  daily,
                ],
                const SizedBox(height: 16),
                latest,
              ],
            );
          },
        ),
      ),
    );
  }
}
