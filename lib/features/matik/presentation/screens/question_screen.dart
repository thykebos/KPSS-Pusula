import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../shared/models/subject.dart';
import '../../domain/entities/answer_result.dart';
import '../../domain/entities/question.dart';
import '../providers/matik_providers.dart';
import '../providers/question_session_controller.dart';
import '../widgets/mnemonic_card.dart';
import '../widgets/option_explanation_list.dart';
import '../widgets/option_tile.dart';
import '../widgets/quota_banner.dart';

const _maxContentWidth = 720.0;

void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.matik);
  }
}

/// Paywall'ı açar; kullanıcı Premium olarak döndüyse soru akışını yeniden başlatır.
Future<void> _openPaywall(
  BuildContext context,
  WidgetRef ref,
  QuestionSessionController controller,
) async {
  await context.push(Routes.paywall);
  if (!context.mounted) return;
  try {
    ref.invalidate(quotaProvider);
    final quota = await ref.read(quotaProvider.future);
    if (quota.isPremium && context.mounted) controller.reload();
  } catch (_) {
    // Kota okunamadıysa ekran olduğu gibi kalır; kullanıcı yeniden deneyebilir.
  }
}

/// Soru çözme ekranı (tam ekran, alt menü yok).
class QuestionScreen extends ConsumerWidget {
  const QuestionScreen({super.key, required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = questionSessionProvider(subject);
    final session = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<SessionState>(provider, (previous, next) {
      final notice = next.notice;
      if (notice != null && next.noticeSeq != (previous?.noticeSeq ?? 0)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(notice)));
      }
    });

    final Widget body = switch (session.phase) {
      SessionPhase.loading => const Center(child: CircularProgressIndicator()),
      SessionPhase.error => ErrorView(
          message: session.error ?? 'Sorular yüklenemedi.',
          onRetry: controller.reload,
        ),
      SessionPhase.limitReached => _EndView(
          icon: Icons.lock_clock,
          title: 'Bugünkü ücretsiz hakkın bitti',
          text: 'Yarın yeni soru hakkın yenilenecek. Sınırsız çözmek için Premium\'a geçebilirsin.',
          session: session,
          primaryLabel: 'Premium ile devam et',
          onPrimary: () => _openPaywall(context, ref, controller),
        ),
      SessionPhase.exhausted => _EndView(
          icon: Icons.emoji_events_outlined,
          title: 'Bu ders için şimdilik soru kalmadı',
          text: 'Yanlış yaptığın sorular ertesi gün tekrar karşına çıkacak. '
              'Yeni sorular eklendikçe de burada görünecek.',
          session: session,
          primaryLabel: 'Derslere dön',
          onPrimary: () => _leave(context),
          showBackLink: false,
        ),
      SessionPhase.answering || SessionPhase.revealed =>
        _QuestionView(session: session, controller: controller),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(subject.label),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Oturumu bitir',
          onPressed: () => _leave(context),
        ),
        actions: [
          if (session.answered > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${session.correct}/${session.answered} doğru'),
              ),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _QuestionView extends ConsumerWidget {
  const _QuestionView({required this.session, required this.controller});

  final SessionState session;
  final QuestionSessionController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final question = session.current;
    if (question == null) return const SizedBox.shrink();

    final quota = ref.watch(quotaProvider).valueOrNull;
    final result = session.result;
    final isRevealed = session.phase == SessionPhase.revealed && result != null;
    final remaining = session.remainingToday ?? quota?.remaining;
    final hint = question.hint?.trim();
    final imageUrl = question.imageUrl;
    final mnemonic = result?.mnemonic?.trim();
    final general = result?.generalExplanation?.trim();

    OptionVisual visualFor(String label) {
      if (result != null && isRevealed) {
        if (label == result.correctOption) return OptionVisual.correct;
        if (label == result.selectedOption) return OptionVisual.wrong;
        return OptionVisual.dimmed;
      }
      if (session.submitting && session.selected == label) {
        return OptionVisual.loading;
      }
      return OptionVisual.idle;
    }

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: ListView(
                // Her soruda yeni anahtar: kaydırma konumu başa döner.
                key: ValueKey(question.id),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (quota != null) ...[
                    QuotaBanner(
                      isPremium: quota.isPremium,
                      remaining: remaining,
                      dailyLimit: quota.dailyLimit,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MetaRow(question: question),
                  const SizedBox(height: 12),
                  Text(
                    question.body,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
                  ),
                  // image_url şu an yalnızca tam URL ise gösterilir (Storage bucket'ı sonraki adımda).
                  if (imageUrl != null && imageUrl.startsWith('http')) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (!isRevealed && hint != null && hint.isNotEmpty)
                    ExpansionTile(
                      key: ValueKey('hint-${question.id}'),
                      tilePadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tips_and_updates_outlined),
                      title: const Text('İpucu'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(hint, style: const TextStyle(height: 1.45))],
                    ),
                  const SizedBox(height: 12),
                  for (final option in question.options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OptionTile(
                        label: option.label,
                        body: option.body,
                        visual: visualFor(option.label),
                        onTap: (isRevealed || session.submitting)
                            ? null
                            : () => controller.answer(option.label),
                      ),
                    ),
                  if (result != null && isRevealed) ...[
                    const SizedBox(height: 6),
                    _ResultBanner(result: result),
                    if (mnemonic != null && mnemonic.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      MnemonicCard(text: mnemonic),
                    ],
                    const SizedBox(height: 16),
                    OptionExplanationList(result: result),
                    if (general != null && general.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _GeneralCard(text: general),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: isRevealed
                  ? FilledButton.icon(
                      onPressed: controller.next,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Sonraki soru'),
                    )
                  : OutlinedButton(
                      onPressed:
                          session.submitting ? null : () => controller.answer(null),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Boş bırak'),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final int d = question.difficulty.clamp(1, 5).toInt();
    final topic = question.topic;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (question.isReview)
          Chip(
            avatar: Icon(Icons.replay, size: 16, color: Theme.of(context).colorScheme.secondary),
            label: const Text('Tekrar sorusu'),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        if (topic != null && topic.isNotEmpty)
          Chip(
            label: Text(topic),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        Text(
          'Zorluk: ${'●' * d}${'○' * (5 - d)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final AnswerResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = result.isCorrect;
    final blank = result.selectedOption == null;
    final color = ok ? successColor(context) : scheme.error;
    final title = ok ? 'Doğru!' : (blank ? 'Boş bıraktın' : 'Yanlış');

    // Öğrenme mekanizması: yanlış/boş soru yarın tekrar gelir; tekrarda doğru yapılan bir daha gelmez.
    final String? followUp = !ok
        ? 'Bu soru yarın tekrar karşına çıkacak.'
        : (result.attemptNo > 1 ? 'Tekrarda doğru yaptın, bu soru artık çıkmayacak.' : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(150)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? title : '$title · Doğru cevap: ${result.correctOption}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                if (followUp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.replay, size: 14, color: color),
                        const SizedBox(width: 4),
                        Expanded(child: Text(followUp)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Konu özeti',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}

class _EndView extends StatelessWidget {
  const _EndView({
    required this.icon,
    required this.title,
    required this.text,
    required this.session,
    required this.primaryLabel,
    required this.onPrimary,
    this.showBackLink = true,
  });

  final IconData icon;
  final String title;
  final String text;
  final SessionState session;
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Birincil düğme zaten "Derslere dön" ise ikinci bağlantı gösterilmez.
  final bool showBackLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center),
              if (session.answered > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Bu oturum: ${session.answered} soru, ${session.correct} doğru',
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
              if (showBackLink)
                TextButton(
                  onPressed: () => _leave(context),
                  child: const Text('Derslere dön'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
