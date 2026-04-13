import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/asterisk_loader.dart';
import '../providers/app_providers.dart';
import '../providers/gallery_providers.dart';

/// The "cool / dude chill" custom permission message screen. Stays on
/// screen for a hard 2 seconds, then fires the system permission dialog.
/// If granted → /home; if denied → /permission.
class AskingPermissionScreen extends ConsumerStatefulWidget {
  final PermissionMessageVariant variant;

  const AskingPermissionScreen({
    super.key,
    required this.variant,
  });

  @override
  ConsumerState<AskingPermissionScreen> createState() =>
      _AskingPermissionScreenState();
}

class _AskingPermissionScreenState
    extends ConsumerState<AskingPermissionScreen> {
  static const _waitDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    // Hard 2-second wait — no skipping.
    await Future<void>.delayed(_waitDuration);
    if (!mounted) return;

    await ref.read(permissionStatusProvider.notifier).requestPermission();
    if (!mounted) return;

    final status = ref.read(permissionStatusProvider);
    if (status == PermissionStatus.granted ||
        status == PermissionStatus.limited) {
      ref.read(photosProvider.notifier).loadInitial();
      context.go('/home');
    } else {
      context.go('/permission');
    }
  }

  String get _headline {
    switch (widget.variant) {
      case PermissionMessageVariant.cool:
        return 'cool,\nfirst let me\naccess the photos on\nyour device';
      case PermissionMessageVariant.chill:
        return 'dude chill,\nfirst let me access the photos on your device';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 120, 20, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Text(
                  _headline,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontFamily: 'Gilroy',
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    height: 0.877,
                    letterSpacing: -1.12,
                  ),
                ),
              ),
              // Rotating asterisk loader at the bottom center.
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: AsteriskLoader(width: 40, height: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
