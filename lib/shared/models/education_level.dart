/// Veritabanındaki `education_level` enum'u ile birebir eşleşir.
enum EducationLevel {
  lise('lise', 'Lise'),
  onlisans('onlisans', 'Önlisans'),
  lisans('lisans', 'Lisans');

  const EducationLevel(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static EducationLevel fromDb(String value) => values.firstWhere(
        (e) => e.dbValue == value,
        orElse: () => EducationLevel.lisans,
      );
}
