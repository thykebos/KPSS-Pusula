import 'package:flutter/material.dart';

import '../../domain/entities/appointment_filter.dart';

/// Filtre sayfası (bottom sheet).
class AppointmentFilterSheet extends StatefulWidget {
  const AppointmentFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  final AppointmentFilter initial;
  final void Function(AppointmentFilter) onApply;

  @override
  State<AppointmentFilterSheet> createState() => _AppointmentFilterSheetState();
}

class _AppointmentFilterSheetState extends State<AppointmentFilterSheet> {
  late TextEditingController _cityCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _qualCtrl;
  late TextEditingController _queryCtrl;

  @override
  void initState() {
    super.initState();
    _cityCtrl = TextEditingController(text: widget.initial.city ?? '');
    _deptCtrl = TextEditingController(text: widget.initial.department ?? '');
    _qualCtrl = TextEditingController(text: widget.initial.qualificationCode ?? '');
    _queryCtrl = TextEditingController(text: widget.initial.query ?? '');
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _deptCtrl.dispose();
    _qualCtrl.dispose();
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrele',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryCtrl,
            decoration: const InputDecoration(
              labelText: 'Ara',
              hintText: 'Örn: hemşire, belediye',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(
              labelText: 'Şehir',
              hintText: 'Örn: Ankara',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deptCtrl,
            decoration: const InputDecoration(
              labelText: 'Bölüm',
              hintText: 'Örn: Kamu Yönetimi',
              prefixIcon: Icon(Icons.school),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qualCtrl,
            decoration: const InputDecoration(
              labelText: 'Nitelik Kodu',
              hintText: 'Örn: 3121',
              prefixIcon: Icon(Icons.numbers),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _cityCtrl.clear();
                    _deptCtrl.clear();
                    _qualCtrl.clear();
                    _queryCtrl.clear();
                    widget.onApply(AppointmentFilter(
                      kpss: widget.initial.kpss,
                      onlyMyProfessions: widget.initial.onlyMyProfessions,
                    ));
                  },
                  child: const Text('Temizle'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () {
                    String? clean(TextEditingController c) =>
                        c.text.trim().isEmpty ? null : c.text.trim();
                    widget.onApply(AppointmentFilter(
                      city: clean(_cityCtrl),
                      department: clean(_deptCtrl),
                      qualificationCode: clean(_qualCtrl),
                      query: clean(_queryCtrl),
                      kpss: widget.initial.kpss,
                      onlyMyProfessions: widget.initial.onlyMyProfessions,
                    ));
                  },
                  child: const Text('Uygula'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}