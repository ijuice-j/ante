import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ZoomApproachesHome extends StatelessWidget {
  const ZoomApproachesHome({super.key});

  static const _approaches = <_Approach>[
    _Approach(
      number: 1,
      title: 'Stacked N-col overlay',
      route: '/zoom-test',
      blurb:
          'Two-grid stack. The 7-col base grid is always mounted. When you '
          'pinch in and release, a real N-col overlay is mounted on top, '
          'scrolled so the focus tile is at your fingers, with a fade-in. '
          'As soon as you start a new pinch, the overlay is disposed and '
          'the base snaps to a matching scale so the zoom-out feels '
          'continuous.',
    ),
    _Approach(
      number: 2,
      title: 'Fixed 7-col canvas, checkpoint lock',
      route: '/zoom-test-2',
      blurb:
          'One grid, fixed 7 cols × 20 rows, forever. Zoom is pure '
          'Transform.scale with snap to checkpoints (7/6/5/4/3/2 visible). '
          'Tile labels are re-mapped so rows read continuously around the '
          'focus row. Top/bottom padding extends the scroll range so the '
          'whole grid is reachable at every zoom level. Non-focus rows '
          'pulse-fade during the snap to hide the label swap.',
    ),
    _Approach(
      number: 3,
      title: '7-col canvas, variable fill',
      route: '/zoom-test-3',
      blurb:
          'One persistent SliverGrid with crossAxisCount = 7. The childCount '
          'grows with the zoom level (140 → 490 slots). A slot-to-item '
          'mapping fills only a contiguous N-column strip; the rest of the '
          'canvas renders as zero-size empty cells. Same visual result as '
          'Approach 1 but without creating or disposing grids — only the '
          'builder output changes.',
    ),
    _Approach(
      number: 4,
      title: 'Dynamic masonry',
      route: '/zoom-test-4',
      blurb:
          'Masonry layout with aspect-ratio tiles. Each zoom level (2–7 '
          'columns) has its own pre-computed layout: 140 photos flow into N '
          'columns, packed into the shortest column by tile height. On '
          'release, Transform.scale animates the old layout to match the '
          'new layout\'s tile width, then we swap grids and jump the scroll '
          'so the focus photo stays put. Uses real photos from the library.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Pinch-zoom approaches',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _approaches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ApproachCard(approach: _approaches[i]),
      ),
    );
  }
}

class _Approach {
  final int number;
  final String title;
  final String? route;
  final String blurb;

  const _Approach({
    required this.number,
    required this.title,
    required this.route,
    required this.blurb,
  });
}

class _ApproachCard extends StatelessWidget {
  final _Approach approach;
  const _ApproachCard({required this.approach});

  @override
  Widget build(BuildContext context) {
    final enabled = approach.route != null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF242424)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => context.push(approach.route!) : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFF1DB954)
                            : const Color(0xFF3A3A3A),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${approach.number}',
                        style: TextStyle(
                          color: enabled ? Colors.black : Colors.white38,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        approach.title,
                        style: TextStyle(
                          color: enabled ? Colors.white : Colors.white54,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (enabled)
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white38,
                        size: 16,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TODO',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  approach.blurb,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
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
