import '../../../core/error/app_exception.dart';
import '../domain/purchase_service.dart';

/// Satın almanın mümkün olmadığı durumlar için (masaüstü, web, anahtar yok).
/// Hiçbir yerel eklentiyi çağırmaz.
class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService(this.reason);

  final String reason;

  @override
  String? get unavailableReason => reason;

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<List<PremiumPackage>> loadPackages() async => const [];

  @override
  Future<PurchaseOutcome> purchase(String packageId) =>
      Future.error(AppException(reason));

  @override
  Future<void> restore() => Future.error(AppException(reason));
}
