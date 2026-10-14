/// Soru çözerken görünen şık. Doğru cevap bilgisi BİLİNÇLİ OLARAK burada yok:
/// sunucu, cevap işaretlenene kadar hangi şıkkın doğru olduğunu istemciye göndermez.
class QuestionOption {
  const QuestionOption({required this.label, required this.body});

  final String label; // 'A'..'E'
  final String body;

  factory QuestionOption.fromMap(Map<String, dynamic> map) => QuestionOption(
        label: (map['label'] as String).trim(),
        body: map['body'] as String,
      );
}

/// get_question_batch() RPC'sinin döndürdüğü tek bir soru.
class Question {
  const Question({
    required this.id,
    required this.body,
    required this.options,
    this.topic,
    this.imageUrl,
    this.difficulty = 2,
    this.hint,
    this.isReview = false,
  });

  final String id;
  final String body;
  final List<QuestionOption> options;
  final String? topic;
  final String? imageUrl;
  final int difficulty; // 1..5
  final String? hint;

  /// true: bu soruyu daha önce yanlış/boş yapmıştın, tekrar önüne çıkıyor.
  final bool isReview;

  factory Question.fromMap(Map<String, dynamic> map) => Question(
        isReview: map['is_review'] as bool? ?? false,
        id: map['id'] as String,
        body: map['body'] as String,
        topic: map['topic'] as String?,
        imageUrl: map['image_url'] as String?,
        difficulty: (map['difficulty'] as num?)?.toInt() ?? 2,
        hint: map['hint'] as String?,
        options: (map['options'] as List? ?? const [])
            .map((e) => QuestionOption.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
