import '../../../shared/models/subject.dart';
import 'entities/answer_result.dart';
import 'entities/question.dart';
import 'entities/quota.dart';

abstract class QuestionRepository {
  /// Kullanıcının eğitim seviyesine uygun, daha önce ÇÖZMEDİĞİ soruları getirir.
  /// Ücretsiz kullanıcı için kota/ders kuralları sunucuda uygulanır; ihlalde
  /// AppException(code: 'daily_limit_reached' | 'subject_not_allowed_for_free_user') fırlatır.
  Future<List<Question>> fetchBatch(Subject subject, {int limit = 10});

  /// Cevabı kaydeder (soru anında "çözüldü" olur) ve doğru şık + her şıkkın açıklamasını döndürür.
  /// [selectedOption] null ise soru boş bırakılmış sayılır.
  Future<AnswerResult> submitAnswer({
    required String questionId,
    required String? selectedOption,
    int? timeSpentSec,
  });

  Future<Quota> fetchQuota();
}
