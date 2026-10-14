import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/education_level.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/education_level_picker.dart';

/// Eğitim seviyesini değiştirme diyaloğu. Kaydedilirse `true` ile kapanır.
class ChangeLevelDialog extends ConsumerStatefulWidget {
  const ChangeLevelDialog({super.key, required this.current});

  final EducationLevel current;

  @override
  ConsumerState<ChangeLevelDialog> createState() => _ChangeLevelDialogState();
}

class _ChangeLevelDialogState extends ConsumerState<ChangeLevelDialog> {
  late EducationLevel _level = widget.current;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_level == widget.current) {
      Navigator.of(context).pop(false);
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      setState(() => _error = 'Oturum bulunamadı. Yeniden giriş yap.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updateEducationLevel(userId: uid, level: _level);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eğitim seviyen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.maxFinite,
            child: EducationLevelPicker(
              value: _level,
              onChanged: _saving ? (_) {} : (l) => setState(() => _level = l),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sorular ve sınav sayacı yeni seviyene göre getirilir. '
            'Daha önce çözdüğün soruların kaydı korunur.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
