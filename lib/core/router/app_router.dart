import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/appointments/presentation/screens/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screens/appointment_list_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/matik/presentation/screens/question_screen.dart';
import '../../features/matik/presentation/screens/subject_select_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/paywall_screen.dart';
import '../../shared/models/subject.dart';
import '../network/supabase_client_provider.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/error_view.dart';
import 'routes.dart';

/// Alt menüsüz, tam ekran sayfalar (soru çözme) bu navigator üzerinde açılır.
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.paywall, builder: (_, __) => const PaywallScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AdaptiveScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.dashboard,
              builder: (_, __) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.matik,
              builder: (_, __) => const SubjectSelectScreen(),
              routes: [
                GoRoute(
                  path: ':subject',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, state) {
                    final subject =
                        Subject.tryFromDb(state.pathParameters['subject'] ?? '');
                    if (subject == null) {
                      return Scaffold(
                        appBar: AppBar(),
                        body: const ErrorView(message: 'Ders bulunamadı.'),
                      );
                    }
                    return QuestionScreen(subject: subject);
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.appointments,
              builder: (_, __) => const AppointmentListScreen(),
              routes: [
                GoRoute(
                  path: 'followed',
                  builder: (_, __) => const AppointmentListScreen(
                    showFollowedOnly: true,
                  ),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (_, state) {
                    final id = state.pathParameters['id'] ?? '';
                    return AppointmentDetailScreen(appointmentId: id);
                  },
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (_, __) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Oturum ve profil durumuna göre yönlendirme kuralları.
String? _redirect(Ref ref, GoRouterState state) {
  final loc = state.matchedLocation;
  final client = ref.read(supabaseProvider);
  final isAuthRoute = loc == Routes.login || loc == Routes.register;

  // 1) Oturum yoksa sadece giriş/kayıt ekranları açık.
  if (client.auth.currentSession == null) {
    return isAuthRoute ? null : Routes.login;
  }

  // 2) Oturum var ama bu kullanıcının profili henüz yüklenmedi -> splash.
  //    (id kontrolü: önceki kullanıcıdan kalan eski profil verisiyle yönlendirmeyi engeller)
  final uid = client.auth.currentUser?.id;
  final profile = ref.read(profileProvider).valueOrNull;
  if (profile == null || profile.id != uid) {
    return loc == Routes.splash ? null : Routes.splash;
  }

  // 3) Ücretsiz ders seçimi yapılmadıysa onboarding.
  if (profile.needsOnboarding) {
    return loc == Routes.onboarding ? null : Routes.onboarding;
  }

  // 4) Her şey tamam; giriş/onboarding/splash ekranlarında kalma.
  if (isAuthRoute || loc == Routes.onboarding || loc == Routes.splash) {
    return Routes.dashboard;
  }
  return null;
}

/// Auth veya profil değiştiğinde GoRouter'ın redirect'i yeniden değerlendirmesini sağlar.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<AsyncValue<Object?>>(authStateProvider, (_, __) => notifyListeners());
    ref.listen<AsyncValue<Object?>>(profileProvider, (_, __) => notifyListeners());
  }
}
