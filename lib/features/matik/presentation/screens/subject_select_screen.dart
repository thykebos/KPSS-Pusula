import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../shared/models/subject.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/quota.dart';
import '../providers/matik_providers.dart';
import '../widgets/quota_banner.dart';

IconData _iconFor(Subject s) => switch (s) {
      Subject.tarih => Icons.account_balance,
      Subject.cografya => Icons.public,
      Subject.vatandaslik => Icons.gavel,
      Subject.matematik => Icons.calculate,
      Subject.turkce => Icons.menu_book,
    };

/// KPSS Matik giriş ekranı: ders seç. Ücretsiz kullanıcıda yalnızca seçtiği 2 ders açıktır.
class SubjectSelectScreen extends ConsumerWidget {
  const SubjectSelectScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, Subject subject) async {
    await context.push(Routes.matikSession(subject.dbValue));
    // Oturumda çözülen sorular kotayı ve ana ekran istatistiklerini değiştirdi; yeniden oku.
    if (context.mounted) {
      ref.invalidate(quotaProvider);
      ref.invalidate(dashboardStatsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(quotaProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('KPSS Matik')),
      body: quotaAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e is AppException ? e.message : 'Bilgiler yüklenemedi.',
          onRetry: () => ref.invalidate(quotaProvider),
        ),
        data: (quota) => _Body(
          quota: quota,
          freeSubjects: profile?.freeSubjects ?? const [],
          levelLabel: profile?.educationLevel.label,
          onOpen: (s) => _open(context, ref, s),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.quota,
    required this.freeSubjects,
    required this.onOpen,
    this.levelLabel,
  });

  final Quota quota;
  final List<Subject> freeSubjects;
  final String? levelLabel;
  final ValueChanged<Subject> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            QuotaBanner(
              isPremium: quota.isPremium,
              remaining: quota.remaining,
              dailyLimit: quota.dailyLimit,
            ),
            const SizedBox(height: 16),
            Text(
              'Ders seç',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (levelLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Sorular $levelLabel seviyene göre getirilir.'),
              ),
            const SizedBox(height: 12),
            for (final subject in Subject.values)
              _SubjectCard(
                subject: subject,
                locked: !quota.isPremium && !freeSubjects.contains(subject),
                isPremium: quota.isPremium,
                onTap: () {
                  final locked = !quota.isPremium && !freeSubjects.contains(subject);
                  if (locked) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: const Text(
                            'Bu ders ücretsiz planında yok. Premium ile tüm derslere eriş.'),
                        action: SnackBarAction(
                          label: 'Premium',
                          onPressed: () => context.push(Routes.paywall),
                        ),
                      ));
                    return;
                  }
                  onOpen(subject);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.locked,
    required this.isPremium,
    required this.onTap,
  });

  final Subject subject;
  final bool locked;
  final bool isPremium;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = locked
        ? 'Premium ile açılır'
        : isPremium
            ? 'Sınırsız'
            : 'Ücretsiz planında';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor:
              (locked ? scheme.outline : scheme.primary).withAlpha(30),
          child: Icon(
            _iconFor(subject),
            color: locked ? scheme.outline : scheme.primary,
          ),
        ),
        title: Text(
          subject.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: locked ? scheme.onSurface.withAlpha(150) : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(locked ? Icons.lock_outline : Icons.chevron_right),
      ),
    );
  }
}
