import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../shared/models/education_level.dart';
import '../../../shared/models/subject.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/user_profile.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required EducationLevel educationLevel,
  }) {
    return _guard(() async {
      // handle_new_user() tetikleyicisi bu metadata'dan public.users satırını oluşturur.
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'education_level': educationLevel.dbValue,
        },
      );
      return res.session == null;
    });
  }

  @override
  Future<void> resendConfirmation(String email) {
    return _guard(() async {
      await _client.auth.resend(type: OtpType.signup, email: email);
    });
  }

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> updateEducationLevel({
    required String userId,
    required EducationLevel level,
  }) {
    return _guard(() async {
      // education_level sütunu istemciye açık (0002 migration'ındaki sütun yetkisi).
      await _client
          .from('users')
          .update({'education_level': level.dbValue}).eq('id', userId);
    });
  }

  @override
  Future<void> updatePassword(String newPassword) {
    return _guard(() async {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    });
  }

  @override
  Future<void> updateFollowedProfessions({
    required String userId,
    required List<String> professions,
  }) {
    return _guard(() async {
      // followed_professions sütunu istemciye açık (0005 migration'ındaki sütun yetkisi).
      await _client
          .from('users')
          .update({'followed_professions': professions}).eq('id', userId);
    });
  }

  @override
  Future<UserProfile?> fetchProfile(String userId) {
    return _guard(() async {
      final row =
          await _client.from('users').select().eq('id', userId).maybeSingle();
      return row == null ? null : UserProfile.fromMap(row);
    });
  }

  @override
  Future<void> completeOnboarding({
    required String userId,
    required List<Subject> freeSubjects,
    String? department,
  }) {
    return _guard(() async {
      final dept = department?.trim();
      if (dept != null && dept.isNotEmpty) {
        await _client.from('users').update({'department': dept}).eq('id', userId);
      }
      // Ders seçimi en sonda: başarısız olursa onboarding tekrar denenebilir.
      // free_subjects sütunu doğrudan güncellenemez (0002 migration), yalnızca bu RPC ile.
      await _client.rpc(
        'set_free_subjects',
        params: {'p_subjects': freeSubjects.map((s) => s.dbValue).toList()},
      );
    });
  }
}
