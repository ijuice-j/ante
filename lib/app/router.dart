import 'package:go_router/go_router.dart';

import '../features/gallery/presentation/pages/gallery_page.dart';
import '../features/gallery/presentation/pages/home_screen.dart';
import '../features/gallery/presentation/pages/launch_screen.dart';
import '../features/gallery/presentation/pages/photo_viewer_page.dart';
import '../features/gallery/presentation/pages/profile_screen.dart';
import '../features/gallery/presentation/pages/zoom_approaches_home.dart';
import '../features/gallery/presentation/pages/zoom_test_page.dart';
import '../features/gallery/presentation/pages/zoom_test_page_2.dart';
import '../features/gallery/presentation/pages/zoom_test_page_3.dart';
import '../features/gallery/presentation/pages/zoom_test_page_4.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Main user flow
    GoRoute(
      path: '/',
      name: 'launch',
      builder: (context, state) => const LaunchScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/viewer',
      name: 'viewer',
      builder: (context, state) {
        final args = state.extra as PhotoViewerArgs;
        return PhotoViewerPage(
          photos: args.photos,
          initialIndex: args.initialIndex,
        );
      },
    ),

    // Legacy / debug routes — not reachable from the main UI, but still
    // work if you navigate to them directly.
    GoRoute(
      path: '/legacy',
      name: 'legacy',
      builder: (context, state) => const ZoomApproachesHome(),
    ),
    GoRoute(
      path: '/gallery',
      name: 'gallery',
      builder: (context, state) => const GalleryPage(),
    ),
    GoRoute(
      path: '/zoom-test',
      name: 'zoom-test',
      builder: (context, state) => const ZoomTestPage(),
    ),
    GoRoute(
      path: '/zoom-test-2',
      name: 'zoom-test-2',
      builder: (context, state) => const ZoomTestPage2(),
    ),
    GoRoute(
      path: '/zoom-test-3',
      name: 'zoom-test-3',
      builder: (context, state) => const ZoomTestPage3(),
    ),
    GoRoute(
      path: '/zoom-test-4',
      name: 'zoom-test-4',
      builder: (context, state) => const ZoomTestPage4(),
    ),
  ],
);
