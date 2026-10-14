import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Supabase/Postgres hatalarını kullanıcıya gösterilecek AppException'a çevirir.
AppException mapError(Object error) {
  if (error is AppException) return error;

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return const AppException('E-posta veya şifre hatalı.');
    }
    if (msg.contains('already registered')) {
      return const AppException('Bu e-posta ile zaten bir hesap var.');
    }
    if (msg.contains('email not confirmed')) {
      return const AppException('E-posta adresin henüz doğrulanmadı.');
    }
    if (msg.contains('different from the old password') ||
        msg.contains('same as the old password')) {
      return const AppException('Yeni şifre eskisinden farklı olmalı.');
    }
    if (msg.contains('reauthentication') || msg.contains('recent login')) {
      return const AppException(
          'Güvenlik için çıkış yapıp yeniden giriş yaptıktan sonra tekrar dene.');
    }
    if (msg.contains('security purposes') ||
        msg.contains('rate limit') ||
        error.statusCode == '429') {
      return const AppException('Çok sık denedin. Biraz bekleyip tekrar dene.');
    }
    if (msg.contains('password')) {
      return const AppException('Şifre en az 6 karakter olmalı.');
    }
    return AppException(error.message);
  }

  if (error is PostgrestException) {
    final text = '${error.message} ${error.details ?? ''}';
    const known = {
      'daily_limit_reached': 'Bugünkü ücretsiz soru hakkın doldu.',
      'subject_not_allowed_for_free_user':
          'Bu ders ücretsiz planında yok. Premium ile tüm derslere eriş.',
      'free_subjects_already_set':
          'Ücretsiz derslerini yalnızca bir kez seçebilirsin.',
      'exactly_two_distinct_subjects_required': 'Birbirinden farklı 2 ders seçmelisin.',
      'already_solved': 'Bu soruyu zaten çözdün.',
      'premium_required': 'Bu özellik yalnızca Premium üyeler içindir.',
      'appointment_not_found': 'İlan bulunamadı.',
    };
    for (final entry in known.entries) {
      if (text.contains(entry.key)) {
        return AppException(entry.value, code: entry.key);
      }
    }
    // unique(user_id, question_id) ihlali
    if (error.code == '23505') {
      return const AppException('Bu soruyu zaten çözdün.', code: 'already_solved');
    }
    return const AppException('Sunucu hatası. Lütfen tekrar dene.');
  }

  return const AppException('Bağlantı hatası. İnternetini kontrol edip tekrar dene.');
}
