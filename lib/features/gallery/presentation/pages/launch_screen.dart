import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../providers/gallery_providers.dart';

/// First screen shown on app launch. Asks for photo library permission;
/// navigates to /home as soon as it's granted (or already was).
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen>
    with WidgetsBindingObserver {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndMaybeProceed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndMaybeProceed();
    }
  }

  Future<void> _checkAndMaybeProceed() async {
    await ref.read(permissionStatusProvider.notifier).checkPermission();
    if (!mounted) return;
    final status = ref.read(permissionStatusProvider);
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      // Kick off the photo load before navigating so Home arrives with
      // data already loading (approach pages only react to permission
      // *transitions*, which won't fire once we're past this screen).
      ref.read(photosProvider.notifier).loadInitial();
      context.go('/home');
    }
  }

  Future<void> _request() async {
    setState(() => _requested = true);
    await ref.read(permissionStatusProvider.notifier).requestPermission();
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
    final status = ref.watch(permissionStatusProvider);
    final showDeniedUi = _requested && status == PermissionStatus.denied;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      size: 44,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ante',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A pinch-zoom sandbox for your photos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const Spacer(flex: 4),
              if (showDeniedUi) ...[
                const Text(
                  'Photo access was denied. Enable it from Settings to '
                  'continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Try again',
                  onPressed: _request,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => PhotoManager.openSetting(),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ] else ...[
                const Text(
                  "We'll need access to your photo library to show your "
                  'photos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _PrimaryButton(
                  label: 'Grant access',
                  onPressed: _request,
                ),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}
