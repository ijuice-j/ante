# ante

A Flutter sandbox exploring pinch-to-zoom behaviours on a photo grid.

Four different approaches are implemented side-by-side, each on its own
route, so they can be compared:

1. **Stacked N-col overlay** (`/zoom-test`) — A fixed 7-col base grid is always
   mounted. On release, a real N-col overlay is mounted on top, scrolled so the
   focus tile lines up with the user's fingers. New gestures dispose the overlay
   and land on the base at a matching scale, so zooming out feels continuous.
2. **Fixed 7-col canvas, checkpoint lock** (`/zoom-test-2`) — A single 7×20
   grid that's purely scaled by `Transform.scale`. On release it snaps to one
   of six checkpoints (7/6/5/4/3/2 visible cols) with the alignment chosen so
   exactly N complete tiles fit the viewport. Non-focus rows fade during the
   snap and tile labels are re-mapped so rows read continuously around the
   focus row.
3. **7-col canvas, variable fill** (`/zoom-test-3`) — One persistent `SliverGrid`
   with `crossAxisCount = 7`. A slot → item mapping fills only a contiguous
   N-column strip; the rest of the canvas renders as empty cells (grey
   placeholders while zooming, transparent at rest). Uses real photos from the
   device library.
4. **Dynamic masonry** (`/zoom-test-4`) — Masonry layout with aspect-ratio
   tiles. Each zoom level has its own pre-computed layout: 140 photos flow
   into N columns packed into the shortest column by tile height. On release
   the grid rebuilds with the new column count and the scroll jumps so the
   focus photo stays put. Uses real photos.

## Architecture

Feature-first with `data` / `domain` / `presentation` layers under
`lib/features/gallery`. State management is Riverpod, routing is GoRouter,
photo access uses `photo_manager`.

```
lib/
├── app/                        # App shell, router, theme
├── core/
│   └── theme/
└── features/gallery/
    ├── data/                   # datasources + repository impl
    ├── domain/                 # entities + repository interface
    └── presentation/
        ├── providers/          # Riverpod notifiers
        ├── pages/              # full-screen routes
        └── widgets/
```

## Running

```bash
flutter pub get
flutter run
```

The app opens on a landing page listing the four approaches; tap one to try it.

Grant photo library access when prompted (approaches 3 and 4 display real
photos; approaches 1 and 2 use numbered colored tiles for testing).
