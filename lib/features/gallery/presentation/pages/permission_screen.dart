import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../providers/gallery_providers.dart';

/// Shown only when the photo-library permission has been denied.
/// Big headline + "Open Settings" call-to-action. Re-checks permission
/// on app resume, so granting in Settings + swiping back to the app
/// automatically navigates to /home.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  static const _bgColor = Color(0xFFF1F1F1);
  static const _ctaColor = Color(0xFFFFEA00);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheck();
    }
  }

  Future<void> _recheck() async {
    await ref.read(permissionStatusProvider.notifier).checkPermission();
    if (!mounted) return;
    final status = ref.read(permissionStatusProvider);
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      ref.read(photosProvider.notifier).loadInitial();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _bgColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 120, 0, 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: Text(
                    'allow\naccess to\nphotos and\nvideos to\nview your\ngallery',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontFamily: 'Gilroy',
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      height: 0.877,
                      letterSpacing: -1.12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => PhotoManager.openSetting(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ctaColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: const Text(
                        'Open Settings',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
