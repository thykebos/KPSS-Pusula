import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/subject.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final Set<Subject> _selected = {};
  final _department = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _department.dispose();
    super.dispose();
  }

  bool get _ready => _selected.length == AppConstants.freeSubjectCount;

  Future<void> _save() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || !_ready) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).completeOnboarding(
            userId: uid,
            freeSubjects: _selected.toList(),
            department: _department.text,
          );
      // Profil yeniden yüklenince router otomatik olarak ana sayfaya yönlendirir.
      ref.invalidate(profileProvider);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const max = AppConstants.freeSubjectCount;
    return AuthShell(
      title: 'Hoş geldin!',
      subtitle:
          'Ücretsiz planda günlük soru çözeceğin $max dersi seç. '
          'Bu seçimi daha sonra değiştiremezsin; Premium ile tüm derslere erişirsin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in Subject.values)
                FilterChip(
                  label: Text(s.label),
                  selected: _selected.contains(s),
                  onSelected: (on) => setState(() {
                    if (on) {
                      if (_selected.length < max) _selected.add(s);
                    } else {
                      _selected.remove(s);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_selected.length}/$max seçildi',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _department,
            decoration: const InputDecoration(
              labelText: 'Bölümün (isteğe bağlı)',
              helperText: 'Atama ilanlarını sana göre filtrelemek için kullanılır.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_ready && !_saving) ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Devam et'),
          ),
        ],
      ),
    );
  }
}
