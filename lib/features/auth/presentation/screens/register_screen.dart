import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../shared/models/education_level.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_shell.dart';
import '../widgets/education_level_picker.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _resendSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  EducationLevel _level = EducationLevel.lisans;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  /// Doğrulama e-postası gönderildiyse bu adres dolu olur ve onay ekranı gösterilir.
  String? _confirmEmail;
  int _cooldown = 0;
  bool _resending = false;
  String? _resendInfo;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown - 1);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      final needsConfirmation = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: _password.text,
            fullName: _name.text.trim(),
            educationLevel: _level,
          );
      if (!mounted) return;
      if (needsConfirmation) {
        setState(() => _confirmEmail = email);
        _startCooldown();
      }
      // Oturum hemen açıldıysa router onboarding'e yönlendirir.
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final email = _confirmEmail;
    if (email == null || _cooldown > 0 || _resending) return;
    setState(() {
      _resending = true;
      _resendInfo = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(email);
      if (!mounted) return;
      setState(() => _resendInfo = 'Onay e-postası yeniden gönderildi.');
      _startCooldown();
    } on AppException catch (e) {
      if (mounted) setState(() => _resendInfo = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmEmail = _confirmEmail;
    if (confirmEmail != null) return _buildConfirmation(context, confirmEmail);

    return AuthShell(
      title: 'Kayıt ol',
      subtitle: 'Eğitim seviyene göre içerikleri sana özel hazırlayalım.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Adını gir' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Geçerli bir e-posta gir' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Şifre',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'En az 6 karakter' : null,
            ),
            const SizedBox(height: 20),
            Text('Eğitim seviyen', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            EducationLevelPicker(
              value: _level,
              onChanged: (l) => setState(() => _level = l),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kayıt ol'),
            ),
            TextButton(
              onPressed: () => context.go(Routes.login),
              child: const Text('Zaten hesabın var mı? Giriş yap'),
            ),
          ],
        ),
      ),
    );
  }

  /// Kayıt sonrası kalıcı "hesabını onayla" ekranı (kısa süreli bildirim değil).
  Widget _buildConfirmation(BuildContext context, String email) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AuthShell(
      title: 'Hesabını onayla',
      subtitle: 'Kaydın oluşturuldu. Giriş yapabilmen için e-posta adresini doğrulaman gerekiyor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.secondary.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.secondary.withAlpha(140)),
            ),
            child: Column(
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 40, color: scheme.secondary),
                const SizedBox(height: 10),
                const Text(
                  'Onay bağlantısını şu adrese gönderdik:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'E-postandaki bağlantıya tıkla, ardından buraya dönüp giriş yap.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'E-posta gelmediyse spam / gereksiz klasörünü kontrol et. '
            'Bu e-posta ile daha önce kayıt olduysan yeni onay e-postası gelmez; '
            'doğrudan giriş yapmayı dene.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go(Routes.login),
            child: const Text('Giriş ekranına git'),
          ),
          TextButton(
            onPressed: (_cooldown > 0 || _resending) ? null : _resend,
            child: Text(
              _cooldown > 0
                  ? 'Onay e-postasını tekrar gönder ($_cooldown sn)'
                  : 'Onay e-postasını tekrar gönder',
            ),
          ),
          if (_resendInfo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _resendInfo!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
