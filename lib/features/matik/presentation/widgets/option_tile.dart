import 'package:flutter/material.dart';

enum OptionVisual {
  /// Henüz cevaplanmadı, tıklanabilir.
  idle,

  /// Bu şık gönderiliyor.
  loading,

  /// Doğru şık (cevap sonrası).
  correct,

  /// Kullanıcının seçtiği yanlış şık (cevap sonrası).
  wrong,

  /// Cevap sonrası diğer şıklar.
  dimmed,
}

/// Açık/koyu temada okunur "doğru" rengi.
Color successColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.body,
    required this.visual,
    this.onTap,
  });

  final String label;
  final String body;
  final OptionVisual visual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color border = switch (visual) {
      OptionVisual.correct => successColor(context),
      OptionVisual.wrong => scheme.error,
      OptionVisual.loading => scheme.primary,
      _ => scheme.outlineVariant,
    };
    final Color fill = switch (visual) {
      OptionVisual.correct => successColor(context).withAlpha(30),
      OptionVisual.wrong => scheme.error.withAlpha(30),
      _ => scheme.surface,
    };

    final Widget? trailing = switch (visual) {
      OptionVisual.correct => Icon(Icons.check_circle, color: successColor(context)),
      OptionVisual.wrong => Icon(Icons.cancel, color: scheme.error),
      OptionVisual.loading => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _ => null,
    };

    final content = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: visual == OptionVisual.idle ? 1 : 1.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: border.withAlpha(40),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(body, style: const TextStyle(height: 1.4)),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );

    return Opacity(
      opacity: visual == OptionVisual.dimmed ? 0.65 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
