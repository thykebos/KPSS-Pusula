import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Profil yüklenirken gösterilir; yükleme başarısız olursa tekrar deneme sunar.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final failed =
        !profile.isLoading && (profile.hasError || profile.valueOrNull == null);

    return Scaffold(
      body: Center(
        child: failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Profil yüklenemedi.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(profileProvider),
                      child: const Text('Tekrar dene'),
                    ),
                    TextButton(
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      child: const Text('Çıkış yap'),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
