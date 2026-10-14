import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../../shared/models/subject.dart';
import '../../domain/entities/answer_result.dart';
import '../../domain/entities/question.dart';
import 'matik_providers.dart';

enum SessionPhase {
  /// Sunucudan soru paketi bekleniyor.
  loading,

  /// Soru gösteriliyor, kullanıcı şık seçecek.
  answering,

  /// Cevap işaretlendi; doğru şık ve açıklamalar gösteriliyor.
  revealed,

  /// Ücretsiz günlük hak bitti.
  limitReached,

  /// Bu ders için çözülmemiş soru kalmadı.
  exhausted,

  /// Yükleme hatası.
  error,
}

class SessionState {
  const SessionState({
    this.phase = SessionPhase.loading,
    this.queue = const [],
    this.index = 0,
    this.selected,
    this.result,
    this.submitting = false,
    this.answered = 0,
    this.correct = 0,
    this.remainingToday,
    this.error,
    this.notice,
    this.noticeSeq = 0,
  });

  final SessionPhase phase;
  final List<Question> queue;
  final int index;

  /// Gönderilmekte olan şık (yalnızca submitting sırasında anlamlı).
  final String? selected;
  final AnswerResult? result;
  final bool submitting;

  /// Bu oturumda işaretlenen / doğru yapılan soru sayısı.
  final int answered;
  final int correct;

  /// Son cevaptan sonra sunucunun bildirdiği kalan hak (Premium'da null).
  final int? remainingToday;

  /// phase == error iken gösterilecek mesaj.
  final String? error;

  /// Geçici uyarı (SnackBar). Aynı metin art arda gelse bile [noticeSeq] artar.
  final String? notice;
  final int noticeSeq;

  Question? get current => index < queue.length ? queue[index] : null;

  SessionState copyWith({
    SessionPhase? phase,
    List<Question>? queue,
    int? index,
    String? selected,
    bool clearSelected = false,
    AnswerResult? result,
    bool clearResult = false,
    bool? submitting,
    int? answered,
    int? correct,
    int? remainingToday,
    String? error,
    bool clearError = false,
    String? notice,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      queue: queue ?? this.queue,
      index: index ?? this.index,
      selected: clearSelected ? null : (selected ?? this.selected),
      result: clearResult ? null : (result ?? this.result),
      submitting: submitting ?? this.submitting,
      answered: answered ?? this.answered,
      correct: correct ?? this.correct,
      remainingToday: remainingToday ?? this.remainingToday,
      error: clearError ? null : (error ?? this.error),
      notice: notice ?? this.notice,
      noticeSeq: notice != null ? noticeSeq + 1 : noticeSeq,
    );
  }
}

/// Bir ders için soru çözme oturumunu yönetir.
///
/// Öğrenme mekanizması:
///  - Şık işaretlendiği AN submit_answer çağrılır; soru sunucuda "çözüldü" olur ve bir daha gelmez.
///  - Sonuçla birlikte doğru şık, her şıkkın açıklaması ve mnemonik gelir.
///  - Yeni paket, yalnızca eldeki sorular bittiğinde istenir (önceden çekilirse
///    henüz işaretlenmemiş sorular tekrar gelebilirdi).
class QuestionSessionController
    extends AutoDisposeFamilyNotifier<SessionState, Subject> {
  static const _batchSize = 10;

  bool _disposed = false;
  DateTime? _shownAt;

  @override
  SessionState build(Subject arg) {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    // build bitmeden state atanamaz; ilk yüklemeyi bir sonraki turda başlat.
    unawaited(Future.microtask(_loadBatch));
    return const SessionState();
  }

  /// Hata ekranındaki "Tekrar dene".
  void reload() => unawaited(_loadBatch());

  Future<void> _loadBatch() async {
    if (_disposed) return;
    state = state.copyWith(phase: SessionPhase.loading, clearError: true);
    try {
      final batch =
          await ref.read(questionRepositoryProvider).fetchBatch(arg, limit: _batchSize);
      if (_disposed) return;
      if (batch.isEmpty) {
        state = state.copyWith(
          phase: SessionPhase.exhausted,
          queue: const [],
          index: 0,
        );
        return;
      }
      _shownAt = DateTime.now();
      state = state.copyWith(
        phase: SessionPhase.answering,
        queue: batch,
        index: 0,
        submitting: false,
        clearSelected: true,
        clearResult: true,
      );
    } catch (e) {
      if (_disposed) return;
      final ex = mapError(e);
      if (ex.code == 'daily_limit_reached') {
        state = state.copyWith(phase: SessionPhase.limitReached, remainingToday: 0);
      } else {
        state = state.copyWith(phase: SessionPhase.error, error: ex.message);
      }
    }
  }

  /// Şıkkı işaretler. [label] null ise soru boş bırakılır (yine "çözüldü" sayılır).
  Future<void> answer(String? label) async {
    final question = state.current;
    if (question == null ||
        state.phase != SessionPhase.answering ||
        state.submitting) {
      return;
    }

    state = state.copyWith(submitting: true, selected: label);
    final shownAt = _shownAt;
    final seconds =
        shownAt == null ? null : DateTime.now().difference(shownAt).inSeconds;

    try {
      final result = await ref.read(questionRepositoryProvider).submitAnswer(
            questionId: question.id,
            selectedOption: label,
            timeSpentSec: seconds,
          );
      if (_disposed) return;
      state = state.copyWith(
        phase: SessionPhase.revealed,
        result: result,
        submitting: false,
        answered: state.answered + 1,
        correct: state.correct + (result.isCorrect ? 1 : 0),
        remainingToday: result.remainingToday,
      );
    } catch (e) {
      if (_disposed) return;
      final ex = mapError(e);
      if (ex.code == 'already_solved') {
        // Soru başka bir cihazda çözülmüş; göstereceğimiz sonuç yok, sıradakine geç.
        state = state.copyWith(
          submitting: false,
          clearSelected: true,
          notice: ex.message,
        );
        _advance();
      } else if (ex.code == 'daily_limit_reached') {
        state = state.copyWith(
          phase: SessionPhase.limitReached,
          submitting: false,
          clearSelected: true,
          remainingToday: 0,
        );
      } else {
        // Ağ vb. geçici hata: soru işaretlenmedi, kullanıcı tekrar deneyebilir.
        state = state.copyWith(
          submitting: false,
          clearSelected: true,
          notice: ex.message,
        );
      }
    }
  }

  /// Sonuç ekranındaki "Sonraki soru".
  void next() {
    if (state.phase != SessionPhase.revealed) return;
    _advance();
  }

  void _advance() {
    final nextIndex = state.index + 1;
    if (nextIndex < state.queue.length) {
      _shownAt = DateTime.now();
      state = state.copyWith(
        phase: SessionPhase.answering,
        index: nextIndex,
        submitting: false,
        clearSelected: true,
        clearResult: true,
      );
      return;
    }

    // Eldeki sorular bitti.
    if (state.remainingToday == 0) {
      state = state.copyWith(phase: SessionPhase.limitReached);
      return;
    }
    unawaited(_loadBatch());
  }
}

final questionSessionProvider = NotifierProvider.autoDispose
    .family<QuestionSessionController, SessionState, Subject>(
  QuestionSessionController.new,
);
