import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Günlük hak göstergesi: Premium için "Sınırsız", ücretsiz için ilerleme çubuğu.
class QuotaBanner extends StatelessWidget {
  const QuotaBanner({
    super.key,
    required this.isPremium,
    this.remaining,
    this.dailyLimit,
  });

  final bool isPremium;

  /// Bugün kalan hak (ücretsiz kullanıcı).
  final int? remaining;
  final int? dailyLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Widget child;
    if (isPremium) {
      child = Row(
        children: [
          Icon(Icons.workspace_premium, color: scheme.secondary),
          const SizedBox(width: 8),
          const Text('Premium · Sınırsız soru'),
        ],
      );
    } else {
      final limit = dailyLimit;
      final left = remaining;
      if (limit == null || left == null) return const SizedBox.shrink();
      final used = math.max(0, math.min(limit, limit - left));
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 18, color: scheme.secondary),
              const SizedBox(width: 6),
              Text('Bugün kalan hak: $left / $limit'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: limit == 0 ? 0 : used / limit,
              minHeight: 6,
              color: left == 0 ? scheme.error : scheme.secondary,
              backgroundColor: scheme.outlineVariant.withAlpha(90),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
