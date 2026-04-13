import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which zoom approach to show on the Home screen.
/// Session-only state — resets to 3 on every app launch.
final selectedApproachProvider =
    NotifierProvider<SelectedApproachNotifier, int>(
  SelectedApproachNotifier.new,
);

class SelectedApproachNotifier extends Notifier<int> {
  @override
  int build() => 3;

  void setApproach(int n) {
    if (n == 3 || n == 4) state = n;
  }
}

/// A randomly-generated letter avatar. The letter and colour are picked
/// once when the provider is first read — since Riverpod providers are
/// created with the `ProviderScope` on app launch, that means a fresh
/// avatar every time the app starts.
class Avatar {
  final String letter;
  final Color color;
  const Avatar({required this.letter, required this.color});
}

final avatarProvider = Provider<Avatar>((ref) {
  final random = Random();
  final letter = String.fromCharCode('A'.codeUnitAt(0) + random.nextInt(26));
  const palette = <Color>[
    Color(0xFFE57373), // red
    Color(0xFFF06292), // pink
    Color(0xFFBA68C8), // purple
    Color(0xFF9575CD), // deep purple
    Color(0xFF7986CB), // indigo
    Color(0xFF64B5F6), // blue
    Color(0xFF4FC3F7), // light blue
    Color(0xFF4DB6AC), // teal
    Color(0xFF81C784), // green
    Color(0xFFFFB74D), // orange
    Color(0xFFFF8A65), // deep orange
    Color(0xFFA1887F), // brown
  ];
  final color = palette[random.nextInt(palette.length)];
  return Avatar(letter: letter, color: color);
});
