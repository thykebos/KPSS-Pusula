import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/appointment_summary.dart';

/// Son atama ilanlarından özet kartlar.
/// Ücretsiz kullanıcıya kilitli kart, Premium kullanıcıya en yeni 3 ilan gösterilir.
class LatestAppointmentsStrip extends StatelessWidget {
  const LatestAppointmentsStrip({
    super.key,
    required this.isPremium,
    required this.appointments,
    required this.onSeeAll,
    required this.onUpgrade,
  });

  final bool isPremium;
  final AsyncValue<List<AppointmentSummary>> appointments;
  final VoidCallback onSeeAll;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
              Icon(Icons.work_outline, color: scheme.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Son atama ilanları',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (isPremium) TextButton(onPressed: onSeeAll, child: const Text('Tümünü gör')),
            ],
          ),
          const SizedBox(height: 8),
          if (!isPremium) ..._locked(context) else ..._list(context),
        ],
      ),
    );
  }

  List<Widget> _locked(BuildContext context) {
    return [
      Row(
        children: [
          const Icon(Icons.lock_outline),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Atama ilanlarını takip etmek ve yeni ilanda bildirim almak Premium üyelere özeldir.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: onUpgrade,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        child: const Text('Premium\'a geç'),
      ),
    ];
  }

  List<Widget> _list(BuildContext context) {
    final state = appointments;
    if (state.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.hasError) {
      return const [Text('İlanlar yüklenemedi. Aşağı çekerek yenileyebilirsin.')];
    }
    final items = state.value ?? const <AppointmentSummary>[];
    if (items.isEmpty) {
      return const [Text('Henüz ilan yok. Yeni ilanlar geldiğinde burada görünecek.')];
    }
    return [for (final a in items) _AppointmentTile(item: a)];
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.item});

  final AppointmentSummary item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final end = item.applicationEnd;
    final subtitle = [
      item.institution,
      if (item.city != null && item.city!.isNotEmpty) item.city!,
    ].join(' · ');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        end == null
            ? subtitle
            : '$subtitle\nSon başvuru: ${DateFormat('d MMM y', 'tr_TR').format(end)}',
      ),
      isThreeLine: end != null,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primary.withAlpha(30),
        child: Icon(Icons.apartment, size: 18, color: theme.colorScheme.primary),
      ),
    );
  }
}
