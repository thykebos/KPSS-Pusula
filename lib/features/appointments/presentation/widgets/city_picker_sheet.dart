import 'package:flutter/material.dart';

import '../../domain/turkish_cities.dart';

/// Şehir seçici: aranabilir 81 il listesi (alttan açılan pencere).
///
/// Dönüş değeri:
///  - seçilen il adı (ör. "Ankara"),
///  - '' (boş metin): "Tüm şehirler" seçildi, yani şehir filtresi kalksın,
///  - null: pencere seçim yapılmadan kapatıldı (hiçbir şey değişmesin).
Future<String?> showCityPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _CityPickerSheet(selected: selected),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({required this.selected});

  final String? selected;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needle = foldTr(_query.trim());
    final cities = needle.isEmpty
        ? turkishCities
        : turkishCities.where((c) => foldTr(c).contains(needle)).toList();
    final showAllTile = needle.isEmpty;

    return Padding(
      // Klavye açılınca liste klavyenin üstünde kalsın.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Şehir seç', style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Şehir ara',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: cities.isEmpty
                  ? Center(
                      child: Text(
                        'Şehir bulunamadı.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      itemCount: cities.length + (showAllTile ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (showAllTile && index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.public),
                            title: const Text('Tüm şehirler'),
                            selected: widget.selected == null,
                            trailing: widget.selected == null
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.of(context).pop(''),
                          );
                        }
                        final city = cities[index - (showAllTile ? 1 : 0)];
                        final isSelected = city == widget.selected;
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(city),
                          selected: isSelected,
                          trailing: isSelected ? const Icon(Icons.check) : null,
                          onTap: () => Navigator.of(context).pop(city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
