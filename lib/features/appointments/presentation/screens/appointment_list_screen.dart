import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/appointment_filter.dart';
import '../providers/appointment_providers.dart';
import '../widgets/appointment_card.dart';
import '../widgets/appointment_filter_bar.dart';

/// İlan listesi ekranı (Premium). Ücretsiz kullanıcıya Premium'a geçiş ekranı gösterilir.
class AppointmentListScreen extends ConsumerStatefulWidget {
  const AppointmentListScreen({super.key, this.showFollowedOnly = false});

  final bool showFollowedOnly;

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState extends ConsumerState<AppointmentListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      ref.read(appointmentListProvider(widget.showFollowedOnly).notifier).loadMore();
    }
  }

  Future<void> _toggleFollow(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final following = await ref
          .read(appointmentListProvider(widget.showFollowedOnly).notifier)
          .toggleFollow(id);
      messenger.showSnackBar(SnackBar(
        content: Text(following ? 'Takip ediliyor' : 'Takipten çıkarıldı'),
        duration: const Duration(seconds: 2),
      ));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('İşlem yapılamadı. Tekrar dene.')));
    }
  }

  void _showFilterSheet() {
    final filter = ref.read(appointmentFilterProvider);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => AppointmentFilterSheet(
        initial: filter,
        onApply: (f) {
          ref.read(appointmentFilterProvider.notifier).replace(f);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final followedOnly = widget.showFollowedOnly;
    final state = ref.watch(appointmentListProvider(followedOnly));
    final notifier = ref.read(appointmentListProvider(followedOnly).notifier);
    final filter = ref.watch(appointmentFilterProvider);
    final hasProfessions =
        (ref.watch(profileProvider).valueOrNull?.followedProfessions ?? const []).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(followedOnly ? 'Takip Edilenler' : 'Atama İlanları'),
        actions: [
          if (!followedOnly) ...[
            IconButton(
              tooltip: 'Takip edilenler',
              icon: const Icon(Icons.bookmark_border),
              onPressed: () => context.push(Routes.appointmentsFollowed),
            ),
            IconButton(
              tooltip: 'Filtrele',
              icon: Badge(
                isLabelVisible: filter.hasSheetFilters,
                smallSize: 8,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: _showFilterSheet,
            ),
          ],
        ],
        bottom: followedOnly
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: _QuickFilters(filter: filter, hasProfessions: hasProfessions),
              ),
      ),
      body: _body(state, notifier, followedOnly),
    );
  }

  Widget _body(AppointmentListState state, AppointmentListController notifier,
      bool followedOnly) {
    if (state.loading) return const Center(child: CircularProgressIndicator());

    final error = state.error;
    if (error != null && state.items.isEmpty) {
      if (error.code == 'premium_required') return const _PremiumRequired();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: notifier.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      final filter = ref.read(appointmentFilterProvider);
      return RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.work_off, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              followedOnly
                  ? 'Henüz takip ettiğin bir ilan yok.'
                  : filter.isActive
                      ? 'Bu filtrelere uyan ilan yok.'
                      : 'Şu an gösterilecek ilan yok. Yeni ilanlar tarandıkça burada listelenir.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (!followedOnly && filter.isActive) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton(
                  onPressed: ref.read(appointmentFilterProvider.notifier).clear,
                  child: const Text('Filtreleri temizle'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = state.items[index];
          return AppointmentCard(
            appointment: item,
            onTap: () => context.push(Routes.appointmentDetail(item.id)),
            onToggleFollow: () => _toggleFollow(item.id),
          );
        },
      ),
    );
  }
}

/// Liste üstündeki hızlı filtreler: KPSS'li / KPSS'siz ve "Mesleklerim".
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters({required this.filter, required this.hasProfessions});

  final AppointmentFilter filter;
  final bool hasProfessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appointmentFilterProvider.notifier);
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final k in KpssFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(k.label),
                selected: filter.kpss == k,
                onSelected: (_) => notifier.setKpss(k),
              ),
            ),
          FilterChip(
            avatar: const Icon(Icons.work_outline, size: 18),
            label: const Text('Mesleklerim'),
            selected: filter.onlyMyProfessions,
            onSelected: (v) {
              if (v && !hasProfessions) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Önce Ayarlar\'dan takip etmek istediğin meslekleri ekle.'),
                ));
                return;
              }
              notifier.setOnlyMyProfessions(v);
            },
          ),
        ],
      ),
    );
  }
}

class _PremiumRequired extends StatelessWidget {
  const _PremiumRequired();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Atama ilanları yalnızca Premium üyelere açıktır.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(Routes.paywall),
              icon: const Icon(Icons.star),
              label: const Text("Premium'a Geç"),
            ),
          ],
        ),
      ),
    );
  }
}
