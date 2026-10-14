import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// "Takip ettiğim meslekler": etiket (chip) şeklinde girilen meslekler.
/// Her değişiklik anında kaydedilir. Premium'daki atama listesi bu mesleklere göre
/// öne çıkarılır ve yeni ilan bildirimi yalnızca bu mesleklerden gelir.
class ProfessionTagsEditor extends ConsumerStatefulWidget {
  const ProfessionTagsEditor({super.key});

  @override
  ConsumerState<ProfessionTagsEditor> createState() => _ProfessionTagsEditorState();
}

class _ProfessionTagsEditorState extends ConsumerState<ProfessionTagsEditor> {
  static const _maxTags = 20;
  static const _suggestions = [
    'Memur', 'Hemşire', 'Zabıt katibi', 'Güvenlik görevlisi', 'Şoför',
    'Teknisyen', 'Mühendis', 'Öğretmen', 'Sağlık personeli', 'Tekniker',
  ];

  final _controller = TextEditingController();
  List<String>? _tags;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _key(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();

  /// Virgül/satır sonuyla ayrılmış girdiyi temiz etiketlere çevirip ekler.
  Future<void> _add(String raw) async {
    final current = [...?_tags];
    var added = false;
    for (final part in raw.split(RegExp(r'[,\n;]'))) {
      final tag = part.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (tag.length < 2 || tag.length > 40) continue;
      if (current.any((t) => _key(t) == _key(tag))) continue;
      if (current.length >= _maxTags) {
        setState(() => _error = 'En fazla $_maxTags meslek ekleyebilirsin.');
        return;
      }
      current.add(tag);
      added = true;
    }
    _controller.clear();
    if (added) await _save(current);
  }

  Future<void> _remove(String tag) =>
      _save([...?_tags]..removeWhere((t) => t == tag));

  Future<void> _save(List<String> next) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final previous = _tags;
    setState(() {
      _tags = next; // iyimser güncelleme
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updateFollowedProfessions(userId: uid, professions: next);
      ref.invalidate(profileProvider);
      ref.invalidate(appointmentListProvider);
    } on AppException catch (e) {
      if (mounted) setState(() {
        _tags = previous;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    _tags ??= List<String>.of(profile.followedProfessions);
    final tags = _tags!;
    final theme = Theme.of(context);
    final suggestions =
        _suggestions.where((s) => !tags.any((t) => _key(t) == _key(s))).take(6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Takip ettiğim meslekler', style: theme.textTheme.titleMedium),
              ),
              if (_saving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Atama ilanlarında bu mesleklere uyanlar öne çıkar ve yeni ilan bildirimi '
            'yalnızca bu mesleklerden gelir. Hiç meslek eklemezsen seviyene uyan tüm ilanlar gelir.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Meslek ekle',
              hintText: 'Örn: Hemşire — Enter ile ekle',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Ekle',
                icon: const Icon(Icons.add),
                onPressed: () => _add(_controller.text),
              ),
            ),
            onSubmitted: _add,
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in tags)
                  InputChip(label: Text(t), onDeleted: () => _remove(t)),
              ],
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Öneriler', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(s),
                    onPressed: () => _add(s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
