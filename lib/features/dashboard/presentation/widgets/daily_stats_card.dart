import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/models/subject.dart';
import '../../domain/entities/dashboard_stats.dart';

/// Bugünkü çözüm istatistikleri + ders bazında toplam dağılım.
class DailyStatsCard extends StatelessWidget {
  const DailyStatsCard({super.key, required this.stats, required this.onStart});

  final DashboardStats stats;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accuracy = stats.accuracyToday;
    final limit = stats.dailyLimit;

    final entries = stats.bySubject.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.isEmpty ? 1 : entries.first.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: scheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Bugün',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(label: 'Çözülen', value: '${stats.solvedToday}'),
              _Metric(label: 'Doğru', value: '${stats.correctToday}'),
              _Metric(
                label: 'Başarı',
                value: accuracy == null ? '-' : '%${(accuracy * 100).round()}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.isPremium)
            Row(
              children: [
                Icon(Icons.workspace_premium, size: 18, color: scheme.secondary),
                const SizedBox(width: 6),
                const Text('Premium · Sınırsız soru'),
              ],
            )
          else if (limit != null) ...[
            Text('Günlük hak: ${math.min(stats.solvedToday, limit)} / $limit'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: limit == 0 ? 0 : math.min(1.0, stats.solvedToday / limit),
                minHeight: 6,
                color: (stats.remainingToday ?? 1) == 0 ? scheme.error : scheme.secondary,
                backgroundColor: scheme.outlineVariant.withAlpha(90),
              ),
            ),
          ],
          if (stats.reviewDue > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.secondary.withAlpha(24),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.secondary.withAlpha(120)),
              ),
              child: Row(
                children: [
                  Icon(Icons.replay, size: 18, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${stats.reviewDue} soru tekrar bekliyor (daha önce yanlış yaptıkların)'),
                  ),
                ],
              ),
            ),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Derslere göre toplam (${stats.totalSolved} soru)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            for (final e in entries) _SubjectBar(subject: e.key, count: e.value, max: maxCount),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Soru çözmeye başla'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.subject, required this.count, required this.max});

  final Subject subject;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(subject.label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : count / max,
                minHeight: 8,
                color: scheme.primary,
                backgroundColor: scheme.outlineVariant.withAlpha(90),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text('$count', textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
