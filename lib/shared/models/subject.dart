/// Veritabanındaki `subject_type` enum'u ile birebir eşleşir.
enum Subject {
  tarih('tarih', 'Tarih'),
  cografya('cografya', 'Coğrafya'),
  vatandaslik('vatandaslik', 'Vatandaşlık'),
  matematik('matematik', 'Matematik'),
  turkce('turkce', 'Türkçe');

  const Subject(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static Subject? tryFromDb(String value) {
    for (final s in values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}
