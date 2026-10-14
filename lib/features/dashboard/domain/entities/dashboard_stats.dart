import 'dart:math' as math;

import '../../../../shared/models/subject.dart';

/// Yaklaşan sınav (public.exams satırı).
class NextExam {
  const NextExam({
    required this.id,
    required this.name,
    required this.examDate,
    this.applicationEnd,
    this.url,
  });

  final String id;
  final String name;

  /// Yerel saate çevrilmiş sınav zamanı.
  final DateTime examDate;
  final DateTime? applicationEnd;
  final String? url;

  factory NextExam.fromMap(Map<String, dynamic> map) {
    final end = map['application_end'] as String?;
    return NextExam(
      id: map['id'] as String,
      name: map['name'] as String,
      examDate: DateTime.parse(map['exam_date'] as String).toLocal(),
      applicationEnd: end == null ? null : DateTime.parse(end).toLocal(),
      url: map['url'] as String?,
    );
  }
}

/// get_dashboard_stats() RPC'sinin sonucu.
class DashboardStats {
  const DashboardStats({
    required this.solvedToday,
    required this.correctToday,
    required this.totalSolved,
    required this.isPremium,
    this.dailyLimit,
    this.bySubject = const {},
    this.nextExam,
    this.reviewDue = 0,
  });

  final int solvedToday;
  final int correctToday;
  final int totalSolved;
  final bool isPremium;

  /// Premium kullanıcıda null (sınırsız).
  final int? dailyLimit;

  /// Ders başına çözülen toplam soru sayısı.
  final Map<Subject, int> bySubject;
  final NextExam? nextExam;

  /// Şu an tekrar edilebilecek (daha önce yanlış yapılmış, günü gelmiş) soru sayısı.
  final int reviewDue;

  int? get remainingToday {
    final limit = dailyLimit;
    if (limit == null) return null;
    return math.max(0, limit - solvedToday);
  }

  /// Bugünkü başarı oranı (0..1); bugün soru çözülmediyse null.
  double? get accuracyToday => solvedToday == 0 ? null : correctToday / solvedToday;

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    final by = <Subject, int>{};
    final rawBy = map['by_subject'];
    if (rawBy is Map) {
      rawBy.forEach((key, value) {
        final subject = Subject.tryFromDb(key as String);
        if (subject != null) by[subject] = (value as num).toInt();
      });
    }
    final exam = map['next_exam'];
    return DashboardStats(
      solvedToday: (map['solved_today'] as num?)?.toInt() ?? 0,
      correctToday: (map['correct_today'] as num?)?.toInt() ?? 0,
      totalSolved: (map['total_solved'] as num?)?.toInt() ?? 0,
      isPremium: map['is_premium'] as bool? ?? false,
      dailyLimit: (map['daily_limit'] as num?)?.toInt(),
      bySubject: by,
      reviewDue: (map['review_due'] as num?)?.toInt() ?? 0,
      nextExam: exam is Map ? NextExam.fromMap(Map<String, dynamic>.from(exam)) : null,
    );
  }
}
