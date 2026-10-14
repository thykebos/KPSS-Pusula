import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/purchase_service.dart';

/// RevenueCat ile gerçek mağaza satın alma. YALNIZCA Android ve iOS'ta oluşturulur
/// (bkz. subscription_providers.dart); diğer platformlarda bu sınıfa hiç dokunulmaz.
///
/// Sürüme duyarlı API'lerden bilerek kaçınıldı: satın almanın dönüş değeri kullanılmaz,
/// sonuç Supabase'deki Premium durumundan (webhook) okunur.
class RevenueCatPurchaseService implements PurchaseService {
  RevenueCatPurchaseService(this._apiKey);

  final String _apiKey;

  bool _configured = false;
  String? _userId;
  final Map<String, Package> _packages = {};

  @override
  String? get unavailableReason => null;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> identify(String userId) {
    return _guard(() async {
      if (!_configured) {
        await Purchases.configure(PurchasesConfiguration(_apiKey)..appUserID = userId);
        _configured = true;
      } else if (_userId != userId) {
        await Purchases.logIn(userId);
      }
      _userId = userId;
    });
  }

  @override
  Future<List<PremiumPackage>> loadPackages() {
    return _guard(() async {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      _packages.clear();
      if (current == null) return const <PremiumPackage>[];

      final result = <PremiumPackage>[];
      for (final p in current.availablePackages) {
        _packages[p.identifier] = p;
        final product = p.storeProduct;
        result.add(PremiumPackage(
          id: p.identifier,
          title: product.title,
          description: product.description,
          priceString: product.priceString,
        ));
      }
      return result;
    });
  }

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    final pkg = _packages[packageId];
    if (pkg == null) {
      throw const AppException('Paket bulunamadı. Ekranı kapatıp yeniden aç.');
    }
    try {
      await Purchases.purchasePackage(pkg);
      return PurchaseOutcome.success;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled;
      }
      throw _mapError(e);
    }
  }

  @override
  Future<void> restore() {
    return _guard(() async {
      await Purchases.restorePurchases();
    });
  }

  AppException _mapError(PlatformException e) {
    switch (PurchasesErrorHelper.getErrorCode(e)) {
      case PurchasesErrorCode.networkError:
        return const AppException('Bağlantı hatası. İnternetini kontrol edip tekrar dene.');
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return const AppException(
            'Bu ürüne zaten sahipsin. "Satın alımları geri yükle" düğmesini dene.');
      case PurchasesErrorCode.paymentPendingError:
        return const AppException(
            'Ödemen onay bekliyor. Onaylandığında Premium otomatik açılır.');
      case PurchasesErrorCode.purchaseNotAllowedError:
        return const AppException('Bu cihazda satın alma izni kapalı.');
      case PurchasesErrorCode.storeProblemError:
        return const AppException('Mağazaya ulaşılamadı. Biraz sonra tekrar dene.');
      default:
        return AppException(e.message ?? 'Satın alma başarısız oldu.');
    }
  }
}
