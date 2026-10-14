import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/education_level.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../matik/presentation/providers/matik_providers.dart';
import '../widgets/change_level_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/profession_tags_editor.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _changeLevel(BuildContext context, WidgetRef ref, EducationLevel current) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ChangeLevelDialog(current: current),
    );
    if (changed == true) {
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(quotaProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Eğitim seviyen güncellendi.')));
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (changed == true) {
      messenger.showSnackBar(const SnackBar(content: Text('Şifren güncellendi.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final isPremium = ref.watch(dashboardStatsProvider).valueOrNull?.isPremium ?? false;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(profile?.fullName ?? '-'),
            subtitle: Text(profile?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: Text(profile?.educationLevel.label ?? '-'),
            subtitle: Text(
              'Ücretsiz dersler: ${profile?.freeSubjects.map((s) => s.label).join(', ') ?? '-'}',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: profile == null ? null : () => _changeLevel(context, ref, profile.educationLevel),
          ),
          const ProfessionTagsEditor(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Şifreni değiştir'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePassword(context),
          ),
          ListTile(
            leading: Icon(Icons.workspace_premium, color: scheme.secondary),
            title: Text(isPremium ? 'Premium üyelik aktif' : 'Ücretsiz plan'),
            subtitle: isPremium
                ? null
                : const Text('Sınırsız soru, tüm dersler ve atama takibi için Premium'),
            trailing: isPremium
                ? null
                : FilledButton.tonal(
                    onPressed: () => context.push(Routes.paywall),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    child: const Text('Yükselt'),
                  ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Tema'),
          ),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
              ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setMode(s.first),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
