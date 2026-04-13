<div align="center">

<img src=".github/assets/img_hero.png" width="400"/>

A Flutter sandbox exploring pinch-to-zoom on a photo grid.

</div>

# ante

**ante** is a small Flutter app built as a take-home exploration of
pinch-to-zoom interactions on a photo gallery. The goal was to land on a
zoom-out/zoom-in behaviour that feels as close as possible to what you get in
Google Photos, where the grid fluidly redistributes tiles across column counts
while the photo under your fingers stays locked in place.

This repo is the result of a week of iteration, many rewrites, and a fair
amount of fighting Flutter's gesture system. Claude Code was my co-engineer on
this one.

<br />

## Onboarding & UX

The flow a first-time user sees:

1. **Native splash**: yellow `#FFEA00`, mascot centered.
2. **Flutter splash**: mascot fades in over 600ms while Poppins fonts preload
   in the background. A hard 1.4s minimum timer runs so there's no flicker.
3. **Dev note**: a short write-up explaining what this app is and how to
   toggle the masonry layout. Shown exactly once; the flag is persisted in
   `SharedPreferences`. Two CTAs ("Cool mahn" / "Stfu and let me see the
   app!") both advance to the permission message, picking one of two copy
   variants.
4. **Custom permission message**: "cool, first let me access the photos on
   your device" in big Gilroy Bold, held on screen for a hard 2 seconds before
   the system permission dialog fires.
5. **Home**: the grid, with a welcome app bar and a gear icon that opens
   Settings.

Settings hosts the masonry toggle, external links (GitHub, Figma, dev note in
read-only mode, report bug), and a hidden developer-mode easter egg: **tap the
build version seven times within three seconds** and a "See Dev Pages" shortcut
appears. The flag is session-only, so it resets on the next cold start.

<br />

## Stack

- **Flutter** 3.41 / **Dart** 3.11
- **Riverpod** for state management
- **GoRouter** for routing, with slide-from-right transitions on every route
- **photo_manager** for device photo access
- **photo_view** for pinch/zoom inside the single-photo viewer
- **flutter_staggered_grid_view** for the masonry layout
- **google_fonts** (Poppins, downloaded) + bundled **Gilroy**
- **flutter_svg** for icons and mascots
- **package_info_plus** + **url_launcher** for settings footer and external
  links

<br />

## Architecture

Feature-first, with `data` / `domain` / `presentation` layers under
`lib/features/gallery`.

```
lib/
├── app/                        # App shell, router, theme
├── core/
│   └── widgets/                # AsteriskLoader and other shared widgets
└── features/gallery/
    ├── data/                   # datasources + repository impl
    ├── domain/                 # entities + repository interface
    └── presentation/
        ├── providers/          # Riverpod notifiers
        ├── pages/              # full-screen routes
        └── widgets/
```

<br />

## Running

```bash
flutter pub get
flutter run
```

Grant photo library access when prompted so the gallery can load real photos
from your device.

<br />

## Links

Every external link below is also wired up inside the app's Settings screen.

- **Design** → [Figma file](https://www.figma.com/design/J4atT9PRRFqufbuR5J4GtI/ante?node-id=1-106)
- **Bugs / feedback** → `ijasahammedj@gmail.com`

<br />

---

<div align="center">

Built by Ijas as a take-home for [Ente](https://ente.com). Thank you for
considering me.

</div>
