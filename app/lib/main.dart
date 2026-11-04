import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'features/login/login_screen.dart';
import 'features/marks/marks_screen.dart';
import 'features/recommendations/recommendations_screen.dart';
import 'features/recommendations/section_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'ui/theme.dart';
import 'ui/vinyl.dart';

void main() => runApp(const ProviderScope(child: VinylssApp()));

final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => authChanges.value = next);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = authChanges.value;
      final atLogin = state.matchedLocation == '/login';
      if (auth.isLoggedIn) return atLogin ? '/' : null;
      // Restoring the saved token or mid-login: stay put ('/' shows a spinner).
      if (auth.loading) return null;
      return atLogin ? null : '/login';
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/marks', redirect: (_, _) => '/library'),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => Consumer(
          builder: (context, ref, _) => ref.watch(authProvider).isLoggedIn
              ? AppShell(shell: shell)
              : const Scaffold(body: LoadingRecord()),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const RecommendationsScreen(),
              routes: [
                GoRoute(
                  path: 'section/:id',
                  builder: (_, state) => SectionScreen(sectionId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (_, _) => const MarksScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});

class VinylssApp extends ConsumerWidget {
  const VinylssApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Vinylss',
      debugShowCheckedModeBanner: false,
      theme: buildVinylssTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
