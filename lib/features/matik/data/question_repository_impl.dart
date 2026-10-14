import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../shared/models/subject.dart';
import '../domain/entities/answer_result.dart';
import '../domain/entities/question.dart';
import '../domain/entities/quota.dart';
import '../domain/question_repository.dart';

class QuestionRepositoryImpl implements QuestionRepository {
  QuestionRepositoryImpl(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<List<Question>> fetchBatch(Subject subject, {int limit = 10}) {
    return _guard(() async {
      final res = await _client.rpc(
        'get_question_batch',
        params: {'p_subject': subject.dbValue, 'p_limit': limit},
      );
      final list = res as List? ?? const [];
      return list
          .map((e) => Question.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  @override
  Future<AnswerResult> submitAnswer({
    required String questionId,
    required String? selectedOption,
    int? timeSpentSec,
  }) {
    return _guard(() async {
      final res = await _client.rpc(
        'submit_answer',
        params: {
          'p_question_id': questionId,
          'p_selected_option': selectedOption,
          'p_time_spent_sec': timeSpentSec,
        },
      );
      return AnswerResult.fromMap(Map<String, dynamic>.from(res as Map));
    });
  }

  @override
  Future<Quota> fetchQuota() {
    return _guard(() async {
      final res = await _client.rpc('get_dashboard_stats');
      return Quota.fromStatsMap(Map<String, dynamic>.from(res as Map));
    });
  }
}
