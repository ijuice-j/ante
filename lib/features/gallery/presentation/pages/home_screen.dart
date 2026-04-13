import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_providers.dart';
import 'zoom_test_page_3.dart';
import 'zoom_test_page_4.dart';

/// Main screen shown once permission is granted. Custom app bar with a
/// "Welcome" heading (Gilroy Bold 24) on the left and a settings icon on
/// the right that opens the Profile screen. Body is an IndexedStack of
/// Approach 3 and Approach 4 so switching between them preserves state.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // App bar content metrics.
  static const _horizontalPad = 40.0;
  static const _topPad = 32.0;
  static const _bottomPad = 24.0;
  static const _contentHeight = 28.0; // welcome text's rendered box height

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approach = ref.watch(selectedApproachProvider);
    final topInset = MediaQuery.paddingOf(context).top;
    final appBarHeight = topInset + _topPad + _contentHeight + _bottomPad;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(appBarHeight),
          child: Material(
            color: Colors.white,
            elevation: 4,
            shadowColor: const Color(0x26000000), // ~15% black
            child: Padding(
              padding: EdgeInsets.only(
                left: _horizontalPad,
                top: topInset + _topPad,
                right: _horizontalPad,
                bottom: _bottomPad,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontFamily: 'Gilroy',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 0.877,
                      letterSpacing: -0.48,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/profile'),
                    child: SvgPicture.asset(
                      'assets/images/ic_settings.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      ),
    );
  }
}
