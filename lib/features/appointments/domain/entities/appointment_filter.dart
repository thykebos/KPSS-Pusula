/// KPSS şartına göre ilan türü.
enum KpssFilter {
  all('all', 'Tümü'),
  kpss('kpss', "KPSS'li"),
  noKpss('nokpss', "KPSS'siz");

  const KpssFilter(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

/// İlan listesinde kullanılan filtreler.
class AppointmentFilter {
  const AppointmentFilter({
    this.city,
    this.department,
    this.qualificationCode,
    this.query,
    this.kpss = KpssFilter.all,
    this.onlyMyProfessions = false,
  });

  final String? city;
  final String? department;
  final String? qualificationCode;

  /// Serbest metin araması (başlık, kurum, şehir, açıklama).
  final String? query;
  final KpssFilter kpss;

  /// Yalnızca Ayarlar'da takip edilen mesleklerle eşleşen ilanlar.
  final bool onlyMyProfessions;

  /// `city` verilirse şehir değişir; `clearCity: true` şehir filtresini kaldırır.
  AppointmentFilter copyWith({
    KpssFilter? kpss,
    bool? onlyMyProfessions,
    String? city,
    bool clearCity = false,
  }) {
    return AppointmentFilter(
      city: clearCity ? null : (city ?? this.city),
      department: department,
      qualificationCode: qualificationCode,
      query: query,
      kpss: kpss ?? this.kpss,
      onlyMyProfessions: onlyMyProfessions ?? this.onlyMyProfessions,
    );
  }

  /// Filtre sayfasındaki alanlar (şehir, bölüm, kod, arama) dolu mu?
  bool get hasSheetFilters =>
      city != null || department != null || qualificationCode != null || query != null;

  bool get isActive =>
      hasSheetFilters || kpss != KpssFilter.all || onlyMyProfessions;

  @override
  bool operator ==(Object other) =>
      other is AppointmentFilter &&
      other.city == city &&
      other.department == department &&
      other.qualificationCode == qualificationCode &&
      other.query == query &&
      other.kpss == kpss &&
      other.onlyMyProfessions == onlyMyProfessions;

  @override
  int get hashCode =>
      Object.hash(city, department, qualificationCode, query, kpss, onlyMyProfessions);
}
