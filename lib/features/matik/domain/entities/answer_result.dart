/// Cevap işaretlendikten sonra sunucunun açığa çıkardığı şık bilgisi.
class OptionReveal {
  const OptionReveal({
    required this.label,
    required this.body,
    required this.isCorrect,
    required this.explanation,
  });

  final String label;
  final String body;
  final bool isCorrect;

  /// Bu şıkkın NEDEN doğru / NEDEN yanlış olduğu.
  final String explanation;

  factory OptionReveal.fromMap(Map<String, dynamic> map) => OptionReveal(
        label: (map['label'] as String).trim(),
        body: map['body'] as String,
        isCorrect: map['is_correct'] as bool,
        explanation: map['explanation'] as String? ?? '',
      );
}

/// submit_answer() RPC'sinin sonucu.
class AnswerResult {
  const AnswerResult({
    required this.isCorrect,
    required this.correctOption,
    required this.options,
    this.selectedOption,
    this.mnemonic,
    this.generalExplanation,
    this.remainingToday,
    this.attemptNo = 1,
    this.reviewTomorrow = false,
  });

  final bool isCorrect;
  final String correctOption;

  /// null = soru boş bırakıldı.
  final String? selectedOption;

  /// Akılda kalıcı çağrışım / ipucu.
  final String? mnemonic;
  final String? generalExplanation;
  final List<OptionReveal> options;

  /// Ücretsiz kullanıcı için bugün kalan hak; Premium için null (sınırsız).
  final int? remainingToday;

  /// Bu soruya kaçıncı kez cevap verildi (1 = ilk kez, 2+ = tekrar).
  final int attemptNo;

  /// Yanlış/boş yapıldıysa true: soru yarın tekrar karşına çıkar. Doğruysa bir daha çıkmaz.
  final bool reviewTomorrow;

  factory AnswerResult.fromMap(Map<String, dynamic> map) => AnswerResult(
        attemptNo: (map['attempt_no'] as num?)?.toInt() ?? 1,
        reviewTomorrow: map['review_tomorrow'] as bool? ?? !(map['is_correct'] as bool),
        isCorrect: map['is_correct'] as bool,
        correctOption: (map['correct_option'] as String).trim(),
        selectedOption: (map['selected_option'] as String?)?.trim(),
        mnemonic: map['mnemonic'] as String?,
        generalExplanation: map['general_explanation'] as String?,
        remainingToday: (map['remaining_today'] as num?)?.toInt(),
        options: (map['options'] as List? ?? const [])
            .map((e) => OptionReveal.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
