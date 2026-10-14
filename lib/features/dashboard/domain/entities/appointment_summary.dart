/// Ana ekrandaki özet kart için ilanın kısa hali.
/// Tam ilan modeli (filtreler, detay) Atama Takip modülünde yazılacak.
class AppointmentSummary {
  const AppointmentSummary({
    required this.id,
    required this.title,
    required this.institution,
    this.city,
    this.applicationEnd,
  });

  final String id;
  final String title;
  final String institution;
  final String? city;
  final DateTime? applicationEnd;

  factory AppointmentSummary.fromMap(Map<String, dynamic> map) {
    final end = map['application_end'] as String?;
    return AppointmentSummary(
      id: map['id'] as String,
      title: map['title'] as String,
      institution: map['institution'] as String,
      city: map['city'] as String?,
      applicationEnd: end == null ? null : DateTime.parse(end).toLocal(),
    );
  }
}
