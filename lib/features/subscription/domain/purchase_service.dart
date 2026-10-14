/// Mağazadan gelen, ekranda gösterilecek abonelik paketi.
class PremiumPackage {
  const PremiumPackage({
    required this.id,
    required this.title,
    required this.description,
    required this.priceString,
  });

  final String id;
  final String title;
  final String description;

  /// Mağazanın yerelleştirilmiş fiyat metni (ör. "₺99,99").
  final String priceString;
}

enum PurchaseOutcome { success, cancelled }

/// Satın alma sağlayıcısı soyutlaması. Premium durumunun GERÇEK kaynağı Supabase'dir
/// (webhook yazar); bu servis yalnızca mağaza akışını yürütür.
abstract class PurchaseService {
  /// null ise satın alma kullanılabilir; aksi hâlde kullanıcıya gösterilecek neden.
  String? get unavailableReason;

  /// Satın almadan ÖNCE çağrılmalıdır: RevenueCat kullanıcısını Supabase kimliğine bağlar
  /// (webhook olayları bu kimlikle gelir).
  Future<void> identify(String userId);

  Future<List<PremiumPackage>> loadPackages();

  Future<PurchaseOutcome> purchase(String packageId);

  /// Önceki satın alımları (yeni cihaz / yeniden kurulum) hesaba geri yükler.
  Future<void> restore();
}
