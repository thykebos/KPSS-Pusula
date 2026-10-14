import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/question_repository_impl.dart';
import '../../domain/entities/quota.dart';
import '../../domain/question_repository.dart';

final questionRepositoryProvider = Provider<QuestionRepository>(
  (ref) => QuestionRepositoryImpl(ref.watch(supabaseProvider)),
);

/// Günlük hak + Premium durumu. Kullanıcı değişirse yeniden yüklenir.
/// Soru çözme oturumundan dönünce ders seçim ekranı bunu invalidate eder.
final quotaProvider = FutureProvider.autoDispose<Quota>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(questionRepositoryProvider).fetchQuota();
});
