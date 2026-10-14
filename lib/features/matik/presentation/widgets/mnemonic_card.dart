import 'package:flutter/material.dart';

/// Doğru cevap için akılda kalıcı çağrışım / ipucu.
class MnemonicCard extends StatelessWidget {
  const MnemonicCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary; // mercan

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akılda kalsın',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: accent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
