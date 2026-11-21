import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/explore/presentation/explore_feed_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/public_profile_screen.dart';
import '../../features/spots/domain/spot_model.dart';
import '../../features/spots/presentation/create/create_spot_screen.dart';
import '../../features/spots/presentation/detail/spot_detail_screen.dart';
import '../../features/spots/presentation/edit/edit_spot_screen.dart';
import '../presentation/main_shell_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen<AsyncValue<User?>>(authStateProvider, (_, _) {
    refreshNotifier.notify();
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/explore',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/explore';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/users/:uid',
        builder: (context, state) {
          final uid = state.pathParameters['uid'] ?? '';
          return PublicProfileScreen(userId: uid);
        },
      ),
      GoRoute(
        path: '/spots/:id/edit',
        builder: (context, state) {
          final spotId = state.pathParameters['id'] ?? '';
          final initialSpot =
              state.extra is SpotModel ? state.extra as SpotModel : null;
          return EditSpotScreen(
            spotId: spotId,
            initialSpot: initialSpot,
          );
        },
      ),
      GoRoute(
        path: '/spots/:id',
        builder: (context, state) {
          final spotId = state.pathParameters['id'] ?? '';
          final initialSpot =
              state.extra is SpotModel ? state.extra as SpotModel : null;
          return SpotDetailScreen(
            spotId: spotId,
            initialSpot: initialSpot,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExploreFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const CreateSpotScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const TabPlaceholderScreen(
                  title: 'Hộp thư',
                  subtitle:
                      'Thông báo tương tác, bình luận và cột mốc lượt thích sẽ được cập nhật ở giai đoạn Thông báo đẩy.',
                  icon: Icons.mail_outline_rounded,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});