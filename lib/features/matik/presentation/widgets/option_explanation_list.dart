import 'package:flutter/material.dart';

import '../../domain/entities/answer_result.dart';
import 'option_tile.dart';

/// Cevap sonrası HER şıkkın neden doğru / neden yanlış olduğunu açıklar.
/// Sıra: önce kullanıcının seçtiği şık (yanlışsa), sonra doğru şık, sonra kalanlar.
class OptionExplanationList extends StatelessWidget {
  const OptionExplanationList({super.key, required this.result});

  final AnswerResult result;

  List<OptionReveal> _ordered() {
    final selected = result.selectedOption;
    final list = [...result.options];
    int rank(OptionReveal o) {
      if (o.label == selected && !o.isCorrect) return 0;
      if (o.isCorrect) return 1;
      return 2;
    }

    // Aynı öncelikteki şıklar etiket sırasıyla (A, B, C...) gelir.
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.label.compareTo(b.label);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final green = successColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Şıklar neden doğru / yanlış?',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final o in _ordered())
          Builder(builder: (context) {
            final isSelected = o.label == result.selectedOption;
            final Color color = o.isCorrect ? green : scheme.error;
            final String title = o.isCorrect
                ? '${o.label} şıkkı · Doğru cevap'
                : isSelected
                    ? '${o.label} şıkkı · Senin cevabın, neden yanlış?'
                    : '${o.label} şıkkı · Neden yanlış?';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: color.withAlpha(isSelected || o.isCorrect ? 24 : 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: color.withAlpha(isSelected || o.isCorrect ? 140 : 60)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(o.isCorrect ? Icons.check_circle : Icons.cancel,
                            size: 18, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: color, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(o.body, style: const TextStyle(fontStyle: FontStyle.italic)),
                    const SizedBox(height: 6),
                    Text(
                      o.explanation.isEmpty ? 'Açıklama eklenmemiş.' : o.explanation,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
