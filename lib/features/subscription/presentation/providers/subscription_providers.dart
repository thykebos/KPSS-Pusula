import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/domain/dashboard_repository.dart';
import '../../data/revenuecat_service.dart';
import '../../data/unavailable_purchase_service.dart';
import '../../domain/purchase_service.dart';

/// Platforma ve yapılandırmaya göre doğru servisi seçer.
/// RevenueCat eklentisi yalnızca Android/iOS'ta, anahtar doluysa oluşturulur.
PurchaseService createPurchaseService() {
  if (kIsWeb) {
    return const UnavailablePurchaseService(
      'Satın alma web sürümünde yapılamaz. Mobil uygulamadan Premium olabilirsin; '
      'aynı hesapla burada da Premium görünür.',
    );
  }

  final String key;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      key = Env.revenueCatAndroidKey;
    case TargetPlatform.iOS:
      key = Env.revenueCatAppleKey;
    default:
      return const UnavailablePurchaseService(
        'Satın alma şu an yalnızca Android ve iOS uygulamalarında yapılabilir. '
        'Telefonundan Premium olursan aynı hesapla burada da Premium görünür.',
      );
  }

  if (key.isEmpty) {
    return UnavailablePurchaseService(
      defaultTargetPlatform == TargetPlatform.android
          ? 'Satın alma henüz yapılandırılmadı (env.json içinde RC_API_KEY_ANDROID boş).'
          : 'Satın alma henüz yapılandırılmadı (env.json içinde RC_API_KEY_APPLE boş).',
    );
  }
  return RevenueCatPurchaseService(key);
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) => createPurchaseService());

/// Paywall açıldığında RevenueCat kullanıcısını Supabase kimliğine bağlar.
final purchaseIdentityProvider = FutureProvider.autoDispose<void>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (service.unavailableReason != null || uid == null) return;
  await service.identify(uid);
});

final premiumPackagesProvider =
    FutureProvider.autoDispose<List<PremiumPackage>>((ref) async {
  final service = ref.watch(purchaseServiceProvider);
  if (service.unavailableReason != null) return const [];
  await ref.watch(purchaseIdentityProvider.future);
  return service.loadPackages();
});

/// Mağaza ödemesi sonrası RevenueCat -> webhook -> Supabase yazımını bekler.
/// Premium görününce true; süre dolarsa false döner (satın alma yine de geçerlidir,
/// yalnızca hesaba yansıması gecikmiştir).
Future<bool> waitForPremium(
  DashboardRepository repository, {
  Duration timeout = const Duration(seconds: 40),
  Duration interval = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final stats = await repository.fetchStats();
      if (stats.isPremium) return true;
    } catch (_) {
      // Geçici ağ hatası: bir sonraki denemede tekrar bak.
    }
    await Future<void>.delayed(interval);
  }
  return false;
}
