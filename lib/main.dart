import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/data/services/firebase_service.dart';
import 'package:family_tree/features/tree_view/tree_screen.dart';
import 'package:family_tree/features/auth/login_page.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:family_tree/features/home/home_page.dart';
import 'package:family_tree/features/group/group_page.dart';
import 'package:family_tree/features/auth/auth_test_page.dart';
import 'package:family_tree/features/auth/landing_page.dart';
import 'package:family_tree/features/auth/link_profile_page.dart';
import 'package:family_tree/features/dashboard/dashboard_page.dart';
import 'package:family_tree/features/admin/admin_dashboard_page.dart';
import 'package:family_tree/features/admin/admin_tree_page.dart';
import 'package:family_tree/features/admin/admin_family_artboard.dart';
import 'package:family_tree/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for immersive experience
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  runApp(
    const ProviderScope(
      child: FamilyTreeApp(),
    ),
  );
}

class FamilyTreeApp extends ConsumerWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Family Tree',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: _createRouter(authStateAsync),
    );
  }

  GoRouter _createRouter(AsyncValue authStateAsync) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authStateAsync),
      redirect: (context, state) {
        // Don't redirect while loading
        if (authStateAsync.isLoading) {
          return null;
        }

        final isAuth = authStateAsync.value != null;
        final location = state.matchedLocation;

        // Redirect authenticated users from login to dashboard
        if (isAuth && location == '/login') {
          return '/dashboard';
        }

        // Protect authenticated routes
        final protectedRoutes = ['/dashboard', '/group', '/home', '/link-profile', '/admin', '/admin/tree'];
        if (!isAuth && protectedRoutes.any((route) => location.startsWith(route))) {
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
          path: '/demo',
          builder: (context, state) => const TreeScreen(
            familyTreeId: 'main-family-tree',
            isDemo: true,
          ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/tree',
          builder: (context, state) {
            // Use main-family-tree which has 100 seeded persons
            return const TreeScreen(
              familyTreeId: 'main-family-tree',
              isDemo: false,
            );
          },
        ),
        GoRoute(
          path: '/group',
          builder: (context, state) => const GroupPage(),
        ),
        GoRoute(
          path: '/auth-test',
          builder: (context, state) => const AuthTestPage(),
        ),
        GoRoute(
          path: '/link-profile',
          builder: (context, state) => const LinkProfilePage(),
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardPage(),
        ),
        GoRoute(
          path: '/admin/tree',
          builder: (context, state) => const AdminTreePage(),
        ),
        GoRoute(
          path: '/admin/artboard',
          builder: (context, state) => const AdminFamilyArtboard(),
        ),
      ],
    );
  }
}

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(AsyncValue authStateAsync) {
    // Listen to auth state changes and notify router
    _subscription = Stream.periodic(const Duration(milliseconds: 100))
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
