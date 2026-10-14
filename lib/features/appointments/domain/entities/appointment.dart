import '../../../../shared/models/education_level.dart';

/// KPSS atama ilanı (tam model).
class Appointment {
  const Appointment({
    required this.id,
    required this.source,
    required this.title,
    required this.institution,
    this.city,
    this.description,
    this.educationLevels = const [],
    this.qualificationCodes = const [],
    this.departments = const [],
    this.positionsCount,
    this.applicationStart,
    this.applicationEnd,
    this.url,
    this.publishedAt,
    this.isFollowing = false,
    this.kpssRequired = true,
    this.matchesProfession = false,
  });

  final String id;
  final String source;
  final String title;
  final String institution;
  final String? city;
  final String? description;
  final List<EducationLevel> educationLevels;
  final List<String> qualificationCodes;
  final List<String> departments;
  final int? positionsCount;
  final DateTime? applicationStart;
  final DateTime? applicationEnd;
  final String? url;
  final DateTime? publishedAt;
  final bool isFollowing;

  /// false: KPSS şartı olmayan ilan (İŞKUR, kamu işçi alımı vb.).
  final bool kpssRequired;

  /// İlan, kullanıcının takip ettiği mesleklerden biriyle eşleşiyor.
  final bool matchesProfession;

  Appointment copyWith({bool? isFollowing}) => Appointment(
        id: id,
        source: source,
        title: title,
        institution: institution,
        city: city,
        description: description,
        educationLevels: educationLevels,
        qualificationCodes: qualificationCodes,
        departments: departments,
        positionsCount: positionsCount,
        applicationStart: applicationStart,
        applicationEnd: applicationEnd,
        url: url,
        publishedAt: publishedAt,
        isFollowing: isFollowing ?? this.isFollowing,
        kpssRequired: kpssRequired,
        matchesProfession: matchesProfession,
      );

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as String,
      source: map['source'] as String? ?? '',
      title: map['title'] as String,
      institution: map['institution'] as String,
      city: map['city'] as String?,
      description: map['description'] as String?,
      educationLevels: _parseLevels(map['education_levels']),
      qualificationCodes: _parseStringList(map['qualification_codes']),
      departments: _parseStringList(map['departments']),
      positionsCount: map['positions_count'] as int?,
      applicationStart: _parseDate(map['application_start']),
      applicationEnd: _parseDate(map['application_end']),
      url: map['url'] as String?,
      publishedAt: _parseDate(map['published_at'] ?? map['created_at']),
      isFollowing: map['is_following'] as bool? ?? false,
      kpssRequired: map['kpss_required'] as bool? ?? true,
      matchesProfession: map['matches_profession'] as bool? ?? false,
    );
  }

  static List<EducationLevel> _parseLevels(dynamic value) {
    if (value is List) {
      return value
          .map((e) => EducationLevel.fromDb(e.toString()))
          .whereType<EducationLevel>()
          .toList();
    }
    return [];
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) return DateTime.parse(value).toLocal();
    return null;
  }
}