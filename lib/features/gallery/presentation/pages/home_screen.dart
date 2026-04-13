import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import 'zoom_test_page_3.dart';
import 'zoom_test_page_4.dart';

/// Main screen shown once permission is granted. A "Welcome" app bar with
/// a random letter avatar on the right; tapping the avatar opens Profile.
/// The body shows whichever approach is currently selected (default 3).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarProvider);
    final approach = ref.watch(selectedApproachProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Welcome',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _AvatarButton(
              avatar: avatar,
              onTap: () => context.push('/profile'),
            ),
          ),
        ],
      ),
      // IndexedStack keeps both approach widgets mounted so switching
      // between them via Profile doesn't tear down and rebuild state.
      body: IndexedStack(
        index: approach == 4 ? 1 : 0,
        children: const [
          ZoomTestPage3(embedded: true),
          ZoomTestPage4(embedded: true),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  final Avatar avatar;
  final VoidCallback onTap;

  const _AvatarButton({required this.avatar, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: avatar.color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          avatar.letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
