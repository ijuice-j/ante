import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_providers.dart';

/// Settings screen. Mirrors the HomeScreen's custom app bar (Gilroy Bold 24
/// with a Material elevation shadow) but swaps the settings icon for a back
/// arrow and uses "Settings" as the title. Body is a circular avatar
/// placeholder (random e1–e4 mascot), a list of setting tiles (the first is
/// a masonry toggle, the rest are external-link placeholders), and a
/// build-version footer.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // App bar content metrics — matches HomeScreen.
  static const _horizontalPad = 40.0;
  static const _topPad = 32.0;
  static const _bottomPad = 24.0;
  static const _contentHeight = 28.0;

  // Easter-egg config.
  static const _tapsToEnableDevMode = 7;
  static const _tapResetWindow = Duration(seconds: 3);

  // Pick a random avatar (e1..e4) once per mount so it doesn't flicker
  // across rebuilds (e.g. when the masonry switch toggles).
  late final String _avatarAsset =
      'assets/images/e${math.Random().nextInt(4) + 1}.svg';

  // Real version name from pubspec (resolved once via package_info_plus).
  String _versionName = '';

  // Tap counter for the build version — in-memory only, per spec.
  int _tapCount = 0;
  Timer? _tapResetTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _versionName = info.version);
  }

  /// Shows a floating SnackBar that sits above the "Build version" text
  /// so the easter-egg toast never covers its own trigger.
  void _showSnack(String message, {Duration? duration}) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        // Clear the version text block: 16 top padding + ~12 text height +
        // 24 bottom padding + safe area + a small visual gap.
        margin: EdgeInsets.fromLTRB(16, 0, 16, safeBottom + 64),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// Build-version tap handler. First 6 taps show a countdown SnackBar,
  /// the 7th flips [devModeProvider] on (session-only) which reveals the
  /// "See Dev Pages" tile. Further taps after unlock just say "you're
  /// already a developer." The counter resets after 3s of idle.
  void _onVersionTap() {
    final devMode = ref.read(devModeProvider);

    if (devMode) {
      _showSnack('You are already a developer');
      return;
    }

    _tapCount += 1;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(_tapResetWindow, () {
      if (!mounted) return;
      _tapCount = 0;
    });

    if (_tapCount >= _tapsToEnableDevMode) {
      _tapCount = 0;
      _tapResetTimer?.cancel();
      ref.read(devModeProvider.notifier).enable();
      _showSnack('Developer mode enabled');
      return;
    }

    final remaining = _tapsToEnableDevMode - _tapCount;
    final times = remaining == 1 ? 'time' : 'times';
    _showSnack(
      'Tap $remaining more $times to enable dev mode',
      duration: const Duration(milliseconds: 1200),
    );
  }

  // Report Bug: open the platform mail composer pre-addressed to the dev.
  Future<void> _reportBug() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'ijasahammedj@gmail.com',
      query: 'subject=Bug report: ante',
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      _showSnack('No mail app available');
    }
  }

  // Opens [url] in the default external browser (not an in-app webview).
  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      _showSnack('Could not open $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final approach = ref.watch(selectedApproachProvider);
    final devMode = ref.watch(devModeProvider);
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
            shadowColor: const Color(0x26000000),
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SvgPicture.asset(
                        'assets/images/ic_back.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ),
                  const Text(
                    'Settings',
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
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar — one of the e1..e4 mascot SVGs, picked at random per
            // mount. Clipped to a circle inside a soft grey backdrop.
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F1F1),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: SvgPicture.asset(
                _avatarAsset,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                children: [
                  _SettingsTile(
                    icon: Icons.dashboard_outlined,
                    label: 'Enable Masonry Layout',
                    trailing: Switch.adaptive(
                      value: approach == 4,
                      onChanged: (v) => ref
                          .read(selectedApproachProvider.notifier)
                          .setApproach(v ? 4 : 3),
                      activeThumbColor: Colors.black,
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.code,
                    label: 'View Github Repo',
                    trailing: const Icon(
                      Icons.arrow_outward,
                      size: 20,
                      color: Colors.black,
                    ),
                    onTap: () =>
                        _openExternal('https://github.com/ijuice-j/ante'),
                  ),
                  _SettingsTile(
                    icon: Icons.brush_outlined,
                    label: 'View Figma Designs',
                    trailing: const Icon(
                      Icons.arrow_outward,
                      size: 20,
                      color: Colors.black,
                    ),
                    onTap: () => _openExternal(
                      'https://www.figma.com/design/J4atT9PRRFqufbuR5J4GtI/ante?node-id=1-106',
                    ),
                  ),
                  _SettingsTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report Bug',
                    trailing: const Icon(
                      Icons.arrow_outward,
                      size: 20,
                      color: Colors.black,
                    ),
                    onTap: _reportBug,
                  ),
                  _SettingsTile(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'View Dev Note',
                    trailing: const Icon(
                      Icons.arrow_outward,
                      size: 20,
                      color: Colors.black,
                    ),
                    onTap: () => context.push('/dev-note', extra: true),
                  ),
                  if (devMode)
                    _SettingsTile(
                      icon: Icons.developer_mode,
                      label: 'See Dev Pages',
                      trailing: const Icon(
                        Icons.arrow_outward,
                        size: 20,
                        color: Colors.black,
                      ),
                      onTap: () => context.push('/legacy'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: 24 + MediaQuery.paddingOf(context).bottom,
                top: 16,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onVersionTap,
                child: Text(
                  _versionName.isEmpty
                      ? 'Build version'
                      : 'Build version $_versionName',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF000000),
                    fontSize: 12,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w300,
                    height: 0.877,
                    letterSpacing: -0.24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single settings row: leading icon, label, trailing widget (Switch or
/// arrow). Tap target covers the whole row when [onTap] is provided.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: -0.32,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
