import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/dashboard_stats.dart';

/// Yaklaşan sınav için geri sayım. Dakikada bir kendini yeniler.
class ExamCountdownCard extends StatefulWidget {
  const ExamCountdownCard({super.key, required this.exam});

  final NextExam? exam;

  @override
  State<ExamCountdownCard> createState() => _ExamCountdownCardState();
}

class _ExamCountdownCardState extends State<ExamCountdownCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exam = widget.exam;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: exam == null
          ? _empty(context, scheme)
          : _countdown(context, scheme, exam),
    );
  }

  Widget _empty(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Icon(Icons.event_busy, color: scheme.onPrimary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Seviyen için şu an yaklaşan bir sınav yok. '
            'Yeni sınav takvimi açıklandığında geri sayım burada görünecek.',
            style: TextStyle(color: scheme.onPrimary),
          ),
        ),
      ],
    );
  }

  Widget _countdown(BuildContext context, ColorScheme scheme, NextExam exam) {
    final diff = exam.examDate.difference(DateTime.now());
    final started = diff.isNegative;
    final days = started ? 0 : diff.inDays;
    final hours = started ? 0 : diff.inHours % 24;
    final minutes = started ? 0 : diff.inMinutes % 60;
    final dateText = DateFormat('d MMMM y, EEEE', 'tr_TR').format(exam.examDate);

    final applicationEnd = exam.applicationEnd;
    final showApplication =
        applicationEnd != null && applicationEnd.isAfter(DateTime.now());

    final onPrimary = scheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, color: onPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exam.name,
                style: TextStyle(
                  color: onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Unit(value: days, label: 'gün', color: onPrimary, big: true),
            const SizedBox(width: 20),
            _Unit(value: hours, label: 'saat', color: onPrimary),
            const SizedBox(width: 20),
            _Unit(value: minutes, label: 'dk', color: onPrimary),
          ],
        ),
        const SizedBox(height: 12),
        Text(dateText, style: TextStyle(color: onPrimary.withAlpha(220))),
        if (showApplication)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Son başvuru: ${DateFormat('d MMMM y', 'tr_TR').format(applicationEnd)}',
              style: TextStyle(color: onPrimary.withAlpha(220)),
            ),
          ),
      ],
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({
    required this.value,
    required this.label,
    required this.color,
    this.big = false,
  });

  final int value;
  final String label;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: big ? Theme.of(context).colorScheme.secondary : color,
            fontSize: big ? 44 : 30,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        Text(label, style: TextStyle(color: color.withAlpha(200))),
      ],
    );
  }
}
