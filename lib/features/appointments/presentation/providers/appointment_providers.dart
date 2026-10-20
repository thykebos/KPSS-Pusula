import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/appointment_repository_impl.dart';
import '../../domain/appointment_repository.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_list.dart';

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------
final appointmentRepositoryProvider = Provider<AppointmentRepository>(
  (ref) => AppointmentRepositoryImpl(ref.watch(supabaseProvider)),
);

// ---------------------------------------------------------------------------
// Filtre durumu
// ---------------------------------------------------------------------------
final appointmentFilterProvider =
    NotifierProvider<AppointmentFilterNotifier, AppointmentFilter>(
  AppointmentFilterNotifier.new,
);

class AppointmentFilterNotifier extends Notifier<AppointmentFilter> {
  @override
  AppointmentFilter build() => const AppointmentFilter();

  void replace(AppointmentFilter filter) => state = filter;
  void setKpss(KpssFilter kpss) => state = state.copyWith(kpss: kpss);
  void setOnlyMyProfessions(bool value) =>
      state = state.copyWith(onlyMyProfessions: value);

  /// Şehir seç; null = şehir filtresini kaldır (tüm şehirler).
  void setCity(String? city) =>
      state = state.copyWith(city: city, clearCity: city == null);
  void clear() => state = const AppointmentFilter();
}

// ---------------------------------------------------------------------------
// Sayfalı ilan listesi (tüm ilanlar / takip edilenler)
// Argüman: true = yalnızca takip edilenler.
// ---------------------------------------------------------------------------
const _pageSize = 20;

class AppointmentListState {
  const AppointmentListState({
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  final List<Appointment> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final AppException? error;

  bool get hasMore => items.length < total;

  AppointmentListState copyWith({
    List<Appointment>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    AppException? error,
    bool clearError = false,
  }) {
    return AppointmentListState(
      items: items ?? this.items,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final appointmentListProvider = NotifierProvider.autoDispose
    .family<AppointmentListController, AppointmentListState, bool>(
  AppointmentListController.new,
);

class AppointmentListController
    extends AutoDisposeFamilyNotifier<AppointmentListState, bool> {
  int _page = 0;
  int _generation = 0; // filtre değişince eski isteklerin sonucu yok sayılır
  bool _disposed = false;

  bool get _followedOnly => arg;

  @override
  AppointmentListState build(bool followedOnly) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    if (!followedOnly) ref.watch(appointmentFilterProvider);
    ref.watch(currentUserIdProvider);
    _generation++;
    _page = 0;
    Future.microtask(_loadFirst);
    return const AppointmentListState();
  }

  Future<void> _loadFirst() async {
    final gen = _generation;
    try {
      final data = await _request(0);
      if (_disposed || gen != _generation) return;
      _page = 0;
      state = AppointmentListState(
        items: data.items,
        total: data.total,
        loading: false,
      );
    } catch (e) {
      if (_disposed || gen != _generation) return;
      state = AppointmentListState(loading: false, error: mapError(e));
    }
  }

  Future<AppointmentList> _request(int page) {
    final repo = ref.read(appointmentRepositoryProvider);
    if (_followedOnly) {
      return repo.fetchFollowedAppointments(page: page, limit: _pageSize);
    }
    return repo.fetchAppointments(
      filter: ref.read(appointmentFilterProvider),
      page: page,
      limit: _pageSize,
    );
  }

  /// Aşağı çekip yenileme: listeyi baştan yükler (mevcut liste yenisi gelene kadar görünür kalır).
  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    _generation++;
    await _loadFirst();
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final data = await _request(_page + 1);
      if (_disposed || gen != _generation) return;
      _page += 1;
      state = state.copyWith(
        items: [...state.items, ...data.items],
        total: data.total,
        loadingMore: false,
      );
    } catch (e) {
      if (_disposed || gen != _generation) return;
      // Sayfa sonuna ulaşılamadı: mevcut liste kalır, tekrar kaydırınca yeniden denenir.
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Takip düğmesi: sunucuya yazar, listeyi yerinde günceller.
  /// Hata olursa AppException fırlatır (arayüz SnackBar gösterir).
  Future<bool> toggleFollow(String id) async {
    final isFollowing =
        await ref.read(appointmentRepositoryProvider).toggleFollow(id);
    if (_disposed) return isFollowing;
    if (_followedOnly && !isFollowing) {
      state = state.copyWith(
        items: state.items.where((a) => a.id != id).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } else {
      state = state.copyWith(
        items: [
          for (final a in state.items)
            if (a.id == id) a.copyWith(isFollowing: isFollowing) else a,
        ],
      );
    }
    // Diğer liste (tümü <-> takip edilenler) bir sonraki açılışta güncel gelsin.
    ref.invalidate(appointmentListProvider(!_followedOnly));
    return isFollowing;
  }
}

// ---------------------------------------------------------------------------
// İlan detayı
// ---------------------------------------------------------------------------
final appointmentDetailProvider =
    FutureProvider.autoDispose.family<Appointment, String>(
  (ref, id) async {
    ref.watch(currentUserIdProvider);
    return ref.watch(appointmentRepositoryProvider).fetchDetail(id);
  },
);

// ---------------------------------------------------------------------------
// Takip toggle (detay ekranı)
// ---------------------------------------------------------------------------
final toggleFollowProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, appointmentId) async {
    final result =
        await ref.read(appointmentRepositoryProvider).toggleFollow(appointmentId);
    ref.invalidate(appointmentListProvider);
    return result;
  },
);
