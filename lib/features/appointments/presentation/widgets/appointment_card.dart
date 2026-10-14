import 'package:flutter/material.dart';

import '../../domain/entities/appointment.dart';

/// İlan kartı (liste içinde kullanılır).
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    required this.onToggleFollow,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İlan adı
              Text(
                appointment.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Kurum + şehir
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      appointment.institution,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (appointment.city != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on, size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      appointment.city!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              if (appointment.matchesProfession || !appointment.kpssRequired) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (appointment.matchesProfession)
                      _Tag(label: 'Mesleğine uygun', color: colorScheme.secondary),
                    if (!appointment.kpssRequired)
                      _Tag(label: "KPSS'siz", color: colorScheme.tertiary),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              // Alt satır: son başvuru + takip düğmesi
              Row(
                children: [
                  if (appointment.applicationEnd != null)
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: _deadlineColor(context)),
                          const SizedBox(width: 4),
                          Text(
                            _deadlineText(appointment.applicationEnd!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _deadlineColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  InkWell(
                    onTap: onToggleFollow,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        appointment.isFollowing
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 20,
                        color: appointment.isFollowing
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _deadlineColor(BuildContext context) {
    if (appointment.applicationEnd == null) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    final diff = appointment.applicationEnd!.difference(DateTime.now());
    if (diff.inDays < 0) return Colors.red;
    if (diff.inDays < 7) return Colors.orange.shade700;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _deadlineText(DateTime end) {
    final diff = end.difference(DateTime.now());
    if (diff.inDays < 0) return 'Süresi doldu';
    if (diff.inDays == 0) {
      if (diff.inHours > 0) return '${diff.inHours} saat kaldı';
      return 'Bugün son gün';
    }
    return '${diff.inDays} gün kaldı';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
