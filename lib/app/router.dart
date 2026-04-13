import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/gallery/presentation/pages/asking_permission_screen.dart';
import '../features/gallery/presentation/pages/dev_note_screen.dart';
import '../features/gallery/presentation/pages/gallery_page.dart';
import '../features/gallery/presentation/pages/home_screen.dart';
import '../features/gallery/presentation/pages/permission_screen.dart';
import '../features/gallery/presentation/pages/photo_viewer_page.dart';
import '../features/gallery/presentation/pages/profile_screen.dart';
import '../features/gallery/presentation/pages/splash_screen.dart';
import '../features/gallery/presentation/pages/zoom_approaches_home.dart';
import '../features/gallery/presentation/pages/zoom_test_page.dart';
import '../features/gallery/presentation/pages/zoom_test_page_2.dart';
import '../features/gallery/presentation/pages/zoom_test_page_3.dart';
import '../features/gallery/presentation/pages/zoom_test_page_4.dart';
import '../features/gallery/presentation/providers/app_providers.dart';

/// Wraps [child] in a `CustomTransitionPage` that slides in from the right
/// on push and slides back out to the right on pop. The page under the
/// incoming one also parallaxes slightly to the left for a natural feel,
/// and reverses when popped.
CustomTransitionPage<void> _slidePage(
  Widget child, {
  required LocalKey key,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Incoming page: from off-screen right to center.
      final incoming = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );

      // The page below: small left parallax while a new page is on top.
      final underneath = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.22, 0),
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
        ),
      );

      return SlideTransition(
        position: incoming,
        child: SlideTransition(
          position: underneath,
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Main user flow
    GoRoute(
      path: '/',
      name: 'splash',
      pageBuilder: (context, state) => _slidePage(
        const SplashScreen(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/dev-note',
      name: 'dev-note',
      pageBuilder: (context, state) => _slidePage(
        const DevNoteScreen(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/asking-permission',
      name: 'asking-permission',
      pageBuilder: (context, state) {
        final variant = (state.extra as PermissionMessageVariant?) ??
            PermissionMessageVariant.cool;
        return _slidePage(
          AskingPermissionScreen(variant: variant),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/permission',
      name: 'permission',
      pageBuilder: (context, state) => _slidePage(
        const PermissionScreen(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      pageBuilder: (context, state) => _slidePage(
        const HomeScreen(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (context, state) => _slidePage(
        const ProfileScreen(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/viewer',
      name: 'viewer',
      pageBuilder: (context, state) {
        final args = state.extra as PhotoViewerArgs;
        return _slidePage(
          PhotoViewerPage(
            photos: args.photos,
            initialIndex: args.initialIndex,
          ),
          key: state.pageKey,
        );
      },
    ),

    // Legacy / debug routes — not reachable from the main UI, but still
    // work if you navigate to them directly.
    GoRoute(
      path: '/legacy',
      name: 'legacy',
      pageBuilder: (context, state) => _slidePage(
        const ZoomApproachesHome(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/gallery',
      name: 'gallery',
      pageBuilder: (context, state) => _slidePage(
        const GalleryPage(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/zoom-test',
      name: 'zoom-test',
      pageBuilder: (context, state) => _slidePage(
        const ZoomTestPage(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/zoom-test-2',
      name: 'zoom-test-2',
      pageBuilder: (context, state) => _slidePage(
        const ZoomTestPage2(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/zoom-test-3',
      name: 'zoom-test-3',
      pageBuilder: (context, state) => _slidePage(
        const ZoomTestPage3(),
        key: state.pageKey,
      ),
    ),
    GoRoute(
      path: '/zoom-test-4',
      name: 'zoom-test-4',
      pageBuilder: (context, state) => _slidePage(
        const ZoomTestPage4(),
        key: state.pageKey,
      ),
    ),
  ],
);
