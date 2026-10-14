import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/router/routes.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../matik/presentation/providers/matik_providers.dart';
import '../../domain/purchase_service.dart';
import '../providers/subscription_providers.dart';

/// Premium satın alma ekranı (tam ekran).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String? _selectedId;
  bool _busy = false;
  String _busyText = '';

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.dashboard);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _refreshPremiumState() {
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(quotaProvider);
  }

  /// Ödeme sonrası Premium'un Supabase'e yansımasını bekler ve sonucu bildirir.
  Future<void> _afterPayment({required bool leaveOnSuccess}) async {
    setState(() => _busyText = 'Ödemen doğrulanıyor…');
    final ok = await waitForPremium(ref.read(dashboardRepositoryProvider));
    if (!mounted) return;
    _refreshPremiumState();
    if (ok) {
      _toast('Premium aktif! İyi çalışmalar.');
      if (leaveOnSuccess) _leave();
    } else {
      _toast(
        'Ödemen alındı ancak hesabına yansıması gecikti. Birkaç dakika sonra '
        'ana sayfayı aşağı çekerek yenile. Olmazsa "Satın alımları geri yükle"yi dene.',
      );
    }
  }

  Future<void> _buy(PurchaseService service) async {
    final id = _selectedId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _busyText = 'Mağaza açılıyor…';
    });
    try {
      final outcome = await service.purchase(id);
      if (!mounted) return;
      if (outcome == PurchaseOutcome.cancelled) return;
      await _afterPayment(leaveOnSuccess: true);
    } catch (e) {
      if (mounted) _toast(mapError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(PurchaseService service) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyText = 'Satın alımlar geri yükleniyor…';
    });
    try {
      await service.restore();
      if (!mounted) return;
      await _afterPayment(leaveOnSuccess: true);
    } catch (e) {
      if (mounted) _toast(mapError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final service = ref.watch(purchaseServiceProvider);
    final isPremium = ref.watch(dashboardStatsProvider).valueOrNull?.isPremium ?? false;
    final reason = service.unavailableReason;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : _leave,
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Icon(Icons.workspace_premium, size: 56, color: scheme.secondary),
              const SizedBox(height: 12),
              Text(
                'KPSS Pusula Premium',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const _Benefit(Icons.all_inclusive, 'Sınırsız soru çözümü'),
              const _Benefit(Icons.menu_book,
                  'Tüm derslere erişim: Tarih, Coğrafya, Vatandaşlık, Matematik, Türkçe'),
              const _Benefit(Icons.work_outline,
                  'Atama ilanlarını nitelik kodu ve bölümüne göre takip et'),
              const _Benefit(Icons.notifications_active_outlined,
                  'Yeni ilan geldiğinde bildirim al'),
              const SizedBox(height: 24),
              if (isPremium)
                _InfoBox(
                  icon: Icons.check_circle,
                  color: scheme.primary,
                  text: 'Premium üyeliğin aktif. Teşekkürler!',
                )
              else if (reason != null)
                _InfoBox(icon: Icons.info_outline, color: scheme.outline, text: reason)
              else
                _Packages(
                  selectedId: _selectedId,
                  busy: _busy,
                  onSelect: (id) => setState(() => _selectedId = id),
                  onDefault: (id) {
                    // İlk paket varsayılan seçili gelsin (build içinde setState çağırmamak için).
                    if (_selectedId == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedId == null) setState(() => _selectedId = id);
                      });
                    }
                  },
                ),
              if (!isPremium && reason == null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: (_busy || _selectedId == null) ? null : () => _buy(service),
                  child: _busy
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(_busyText),
                          ],
                        )
                      : const Text('Premium\'a geç'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _restore(service),
                  child: const Text('Satın alımları geri yükle'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Abonelikler mağaza hesabın üzerinden yönetilir; dilediğin zaman '
                  'mağaza ayarlarından iptal edebilirsin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Packages extends ConsumerWidget {
  const _Packages({
    required this.selectedId,
    required this.busy,
    required this.onSelect,
    required this.onDefault,
  });

  final String? selectedId;
  final bool busy;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDefault;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final packages = ref.watch(premiumPackagesProvider);

    return packages.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InfoBox(
        icon: Icons.error_outline,
        color: scheme.error,
        text: e is AppException ? e.message : 'Paketler yüklenemedi. Daha sonra tekrar dene.',
        action: TextButton(
          onPressed: () => ref.invalidate(premiumPackagesProvider),
          child: const Text('Tekrar dene'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _InfoBox(
            icon: Icons.info_outline,
            color: scheme.outline,
            text: 'Şu an satın alınabilir paket bulunamadı. '
                '(RevenueCat panelinde bir "current offering" tanımlı olmalı.)',
          );
        }
        onDefault(list.first.id);
        return Column(
          children: [
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PackageTile(
                  package: p,
                  selected: p.id == selectedId,
                  onTap: busy ? null : () => onSelect(p.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, required this.selected, this.onTap});

  final PremiumPackage package;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = selected ? scheme.secondary : scheme.outlineVariant;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? scheme.secondary.withAlpha(24) : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: border),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (package.description.isNotEmpty)
                      Text(package.description,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                package.priceString,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.color, required this.text, this.action});

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
            ],
          ),
          if (action != null) Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }
}
