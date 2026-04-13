import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_providers.dart';
import '../providers/gallery_providers.dart';

/// First thing shown on app launch. Displays the logo and name with a
/// fade-in, runs the permission check + dev-note-seen check in parallel
/// with a minimum display duration, then routes:
///   /home              — if permission granted (regardless of dev note),
///   /permission        — if denied AND the dev note has already been seen,
///   /dev-note          — if denied AND the dev note has NOT been seen.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minDisplay = Duration(milliseconds: 1400);

  late final AnimationController _fadeCtl;

  @override
  void initState() {
    super.initState();
    _fadeCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Wait for the first frame before touching providers so the tree is
    // fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  @override
  void dispose() {
    _fadeCtl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    // Always honor the minimum display duration.
    final minDelay = Future<void>.delayed(_minDisplay);

    // Pre-download every Poppins weight the Dev Note screen uses so we
    // don't see a fallback-font flash on first launch. Runs in parallel
    // with everything else.
    final fontsLoaded = GoogleFonts.pendingFonts([
      GoogleFonts.poppins(fontWeight: FontWeight.w300),
      GoogleFonts.poppins(fontWeight: FontWeight.w500),
      GoogleFonts.poppins(fontWeight: FontWeight.w600),
      GoogleFonts.poppins(fontWeight: FontWeight.w800),
      GoogleFonts.poppins(fontWeight: FontWeight.w900),
    ]);

    final devNoteSeen = await ref.read(devNoteSeenProvider.future);

    // On a true first launch (dev note not yet seen), don't call
    // `photo_manager` at all — `requestPermissionExtend` would pop the
    // OS permission dialog during the splash, before the user ever sees
    // the dev note. The real request happens later in
    // AskingPermissionScreen.
    //
    // On subsequent launches, the dev note has been seen, so the OS has
    // already made a decision; `requestPermissionExtend` returns the
    // cached state without showing another dialog.
    PermissionStatus status = PermissionStatus.unknown;
    if (devNoteSeen) {
      await ref.read(permissionStatusProvider.notifier).checkPermission();
      status = ref.read(permissionStatusProvider);
    }

    await Future.wait([minDelay, fontsLoaded]);
    if (!mounted) return;

    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      ref.read(photosProvider.notifier).loadInitial();
      context.go('/home');
      return;
    }

    // Permission denied / unknown — branch on whether the dev note has
    // already been seen.
    if (devNoteSeen) {
      context.go('/permission');
    } else {
      context.go('/dev-note');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEA00),
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fadeCtl, curve: Curves.easeOut),
          child: SvgPicture.asset(
            'assets/images/ic_ante.svg',
            width: 120,
            height: 120,
          ),
        ),
      ),
    );
  }
}
