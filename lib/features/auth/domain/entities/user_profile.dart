import '../../../../core/config/app_constants.dart';
import '../../../../shared/models/education_level.dart';
import '../../../../shared/models/subject.dart';

/// public.users tablosundaki satırın uygulama içi karşılığı (saf Dart).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.educationLevel,
    this.email,
    this.fullName,
    this.department,
    this.qualificationCodes = const [],
    this.freeSubjects = const [],
    this.followedProfessions = const [],
  });

  final String id;
  final String? email;
  final String? fullName;
  final EducationLevel educationLevel;
  final String? department;
  final List<String> qualificationCodes;
  final List<Subject> freeSubjects;

  /// Kullanıcının takip etmek istediği meslekler (etiketler). Ayarlar'dan düzenlenir.
  final List<String> followedProfessions;

  /// Ücretsiz ders seçimi tamamlanmadıysa onboarding gösterilir.
  bool get needsOnboarding => freeSubjects.length < AppConstants.freeSubjectCount;

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      educationLevel: EducationLevel.fromDb(map['education_level'] as String),
      department: map['department'] as String?,
      qualificationCodes:
          List<String>.from(map['qualification_codes'] as List? ?? const []),
      freeSubjects: (map['free_subjects'] as List? ?? const [])
          .map((e) => Subject.tryFromDb(e as String))
          .whereType<Subject>()
          .toList(),
      followedProfessions:
          List<String>.from(map['followed_professions'] as List? ?? const []),
    );
  }
}
