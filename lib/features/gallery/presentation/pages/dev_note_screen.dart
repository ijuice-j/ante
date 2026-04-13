import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/app_providers.dart';

/// The first-run dev note. Shown exactly once, before any permission
/// prompt. Tapping either CTA flips `devNoteSeenProvider` → true and
/// routes to the custom permission message (variant depends on the
/// button).
///
/// When [readOnly] is true, the screen is being viewed from the Settings
/// page — in that mode a back button replaces the CTAs at the top and the
/// bottom CTAs are hidden.
class DevNoteScreen extends ConsumerWidget {
  const DevNoteScreen({super.key, this.readOnly = false});

  final bool readOnly;

  static const _bgColor = Color(0xFFF1F1F1);
  static const _ctaColor = Color(0xFFFFEA00);
  // #CCBB00 at 5% opacity for the fill, 30% for the 1px inside stroke.
  static const _secondaryCtaColor = Color(0x0DCCBB00);
  static const _secondaryCtaBorder = Color(0x4DCCBB00);

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    PermissionMessageVariant variant,
  ) async {
    await ref.read(devNoteSeenProvider.notifier).markSeen();
    if (!context.mounted) return;
    context.go('/asking-permission', extra: variant);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _bgColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top row. Empty by default; in read-only mode we surface a
              // back button here so the user can return to Settings.
              if (readOnly)
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      child: SvgPicture.asset(
                        'assets/images/ic_back.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Scrollable note body.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: SvgPicture.asset(
                          'assets/images/ic_ante.svg',
                          width: 39,
                          height: 42,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'hey yo,',
                        style: GoogleFonts.poppins(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'First of all, thank you so much team Ente for '
                        'considering me. This was a really good task.',
                        style: _bodyStyle(),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "I tried multiple approaches to implement the "
                        "pinch-to-zoom effect, and I wouldn't say I'm 100% "
                        "happy with the current result, but this is the version that I believe most closely "
                        "resembles the behaviour shown in the task reference "
                        "video. I'm sure there's a better way to do this (always).",
                        style: _bodyStyle(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Masonry Layout',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF000000),
                          fontSize: 14,
                          fontStyle: FontStyle.normal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "To switch to the Masonry layout, tap the settings icon at the top of the home screen and toggle it on.",
                        style: _bodyStyle(),
                      ),
                      // const SizedBox(height: 18),    Text(
                      //   'Dummy Network Images',
                      //   style: GoogleFonts.poppins(
                      //     color: const Color(0xFF000000),
                      //     fontSize: 14,
                      //     fontStyle: FontStyle.normal,
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      // ),
                      // const SizedBox(height: 4),
                      // Text(
                      //   "If you don't want to give permission to your photos and media "
                      //   "you can use dummy network images. To do this, first deny the permission when asked and choose Use Network images option"
                      //  ,
                      //   style: _bodyStyle(),
                      // ),
                      const SizedBox(height: 16),
                      Text(
                        'Again thank you for considering this and yes, '
                        'Claude code was my co-engineer on this one.',
                        style: _bodyStyle(),
                      ),
                      const SizedBox(height: 18),
                      Text('Best,', style: _bodyStyle()),
                      Text('Ijas', style: _bodyStyle()),
                    ],
                  ),
                ),
              ),

              // CTAs (first-run only — hidden when viewed from Settings).
              if (!readOnly) ...[
                const SizedBox(height: 12),
                _CtaButton(
                  label: 'Cool mahn',
                  color: _ctaColor,
                  onTap: () =>
                      _finish(context, ref, PermissionMessageVariant.cool),
                ),
                const SizedBox(height: 8),
                _CtaButton(
                  label: 'Stfu and let me see the app!',
                  color: _secondaryCtaColor,
                  borderColor: _secondaryCtaBorder,
                  onTap: () =>
                      _finish(context, ref, PermissionMessageVariant.chill),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  static TextStyle _bodyStyle() {
    return GoogleFonts.poppins(
      color: const Color(0xFF000000),
      fontSize: 14,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w300,
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? borderColor;
  final VoidCallback onTap;

  const _CtaButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = borderColor == null
        ? BorderSide.none
        : BorderSide(color: borderColor!, width: 1);

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          elevation: 0,
          // Inside-stroke behavior: StadiumBorder/Rectangle handles the
          // border on the inside of the button bounds by default.
          side: border,
          shape: RoundedRectangleBorder(
            side: border,
            borderRadius: BorderRadius.circular(0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFF000000),
            fontSize: 14,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
