import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/appointment_providers.dart';
import '../../domain/entities/appointment.dart';

/// İlan detay ekranı.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(appointmentDetailProvider(appointmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('İlan Detayı')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text(err.toString())),
        data: (app) => _DetailContent(app: app, ref: ref),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.app, required this.ref});

  final Appointment app;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Başlık + Kurum
        Text(
          app.title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.business, size: 18, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(app.institution, style: theme.textTheme.bodyLarge),
          ],
        ),
        if (app.city != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on, size: 18, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(app.city!, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
        const SizedBox(height: 16),

        // Takip düğmesi
        FilledButton.tonalIcon(
          onPressed: () => _toggleFollow(context),
          icon: Icon(app.isFollowing ? Icons.bookmark : Icons.bookmark_border),
          label: Text(app.isFollowing ? 'Takip Ediliyor' : 'Takip Et'),
        ),
        if (app.url != null && app.url!.isNotEmpty) ...[
          const SizedBox(height: 8),
          // Dar ekranda ikinci düğme alta geçer (Wrap), taşma olmaz.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openLink(context, app.url!),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Bağlantıya Git'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: app.url!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('İlan bağlantısı panoya kopyalandı.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Bağlantıyı Kopyala'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),

        // Detay başlıkları
        if (app.description != null && app.description!.isNotEmpty) ...[
          _SectionHeader(title: 'Açıklama'),
          const SizedBox(height: 4),
          Text(app.description!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],

        _InfoRow(label: 'Kaynak', value: _sourceLabel(app.source)),
        if (app.positionsCount != null)
          _InfoRow(label: 'Kontenjan', value: '${app.positionsCount}'),

        // Eğitim seviyeleri
        if (app.educationLevels.isNotEmpty)
          _InfoRow(
            label: 'Eğitim Seviyesi',
            value: app.educationLevels.map((e) => e.label).join(', '),
          ),

        // Bölümler
        if (app.departments.isNotEmpty)
          _InfoRow(
            label: 'Bölümler',
            value: app.departments.join(', '),
          ),

        // KPSS nitelik kodları
        if (app.qualificationCodes.isNotEmpty)
          _InfoRow(
            label: 'Nitelik Kodları',
            value: app.qualificationCodes.join(', '),
          ),

        // Başvuru tarihleri
        if (app.applicationStart != null)
          _InfoRow(
            label: 'Başvuru Başlangıç',
            value: _formatDate(app.applicationStart!),
          ),
        if (app.applicationEnd != null)
          _InfoRow(
            label: 'Başvuru Bitiş',
            value: _formatDate(app.applicationEnd!),
          ),

        if (app.publishedAt != null)
          _InfoRow(
            label: 'Yayın Tarihi',
            value: _formatDate(app.publishedAt!),
          ),
      ],
    );
  }

  Future<void> _toggleFollow(BuildContext context) async {
    try {
      final newStatus = await ref.read(toggleFollowProvider(app.id).future);
      ref.invalidate(appointmentDetailProvider(app.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Takip ediliyor' : 'Takipten çıkarıldı'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${e.toString()}')),
        );
      }
    }
  }

  /// İlan bağlantısını telefonun tarayıcısında açar. Yalnızca http/https açılır (veri bottan geliyor;
  /// "javascript:", "tel:" gibi şemalar açılmaz). Şemasız adres ("www.x.gov.tr") https sayılır.
  Future<void> _openLink(BuildContext context, String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    const failMessage =
        'Bağlantı açılamadı. Bağlantıyı kopyalayıp tarayıcıda açabilirsin.';
    final uri = _parseWebUri(raw);
    if (uri == null) {
      messenger.showSnackBar(const SnackBar(content: Text(failMessage)));
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(const SnackBar(content: Text(failMessage)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(failMessage)));
    }
  }

  Uri? _parseWebUri(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.contains('://')) text = 'https://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'kariyerkapisi':
        return 'Kariyer Kapısı';
      case 'kariyerkapisi_isealim':
        return 'Kariyer Kapısı (İş e-Alım)';
      case 'iskur_esube':
        return 'İŞKUR (e-Şube)';
      case 'resmigazete':
        return 'Resmî Gazete';
      case 'yerelyonetimler':
        return 'Yerel Yönetimler';
      case 'pgm_adalet':
        return 'Adalet Bakanlığı (PGM)';
      case 'iskur':
        return 'İŞKUR';
      case 'kamuilan':
        return 'Kamu İlan';
      case 'ilan_gov':
        return 'ilan.gov.tr';
      case 'sayistay':
        return 'Sayıştay';
      case 'osym':
        return 'ÖSYM';
      default:
        return source;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}