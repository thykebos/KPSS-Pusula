import 'dart:math' as math;

/// Kullanıcının günlük soru hakkı ve Premium durumu.
/// Kaynak: get_dashboard_stats() RPC'si (ana ekran adımında aynı RPC'den başka alanlar da okunacak).
class Quota {
  const Quota({
    required this.isPremium,
    required this.solvedToday,
    this.dailyLimit,
  });

  final bool isPremium;
  final int solvedToday;

  /// Premium kullanıcıda null (sınırsız).
  final int? dailyLimit;

  /// Bugün kalan hak; sınırsızsa null.
  int? get remaining {
    final limit = dailyLimit;
    if (limit == null) return null;
    return math.max(0, limit - solvedToday);
  }

  factory Quota.fromStatsMap(Map<String, dynamic> map) => Quota(
        isPremium: map['is_premium'] as bool? ?? false,
        solvedToday: (map['solved_today'] as num?)?.toInt() ?? 0,
        dailyLimit: (map['daily_limit'] as num?)?.toInt(),
      );
}
