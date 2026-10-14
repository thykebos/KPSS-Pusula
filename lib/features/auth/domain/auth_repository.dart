import '../../../shared/models/education_level.dart';
import '../../../shared/models/subject.dart';
import 'entities/user_profile.dart';

abstract class AuthRepository {
  Future<void> signIn({required String email, required String password});

  /// E-posta doğrulaması gerekiyorsa `true` döner (oturum hemen açılmaz).
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required EducationLevel educationLevel,
  });

  /// Kayıt sonrası e-posta doğrulama bağlantısını yeniden gönderir.
  Future<void> resendConfirmation(String email);

  Future<void> signOut();

  /// Oturum açmış kullanıcının eğitim seviyesini değiştirir (içerik yeni seviyeye göre filtrelenir).
  Future<void> updateEducationLevel({
    required String userId,
    required EducationLevel level,
  });

  /// Oturum açmış kullanıcının şifresini değiştirir.
  Future<void> updatePassword(String newPassword);

  /// Takip edilen meslek etiketlerini kaydeder (tam liste).
  Future<void> updateFollowedProfessions({
    required String userId,
    required List<String> professions,
  });

  Future<UserProfile?> fetchProfile(String userId);

  Future<void> completeOnboarding({
    required String userId,
    required List<Subject> freeSubjects,
    String? department,
  });
}
