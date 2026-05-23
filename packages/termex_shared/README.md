# termex_shared

> Shared Dart code reused by both the desktop (`termex/app`) and mobile (`termex-mobile/app`) Flutter apps.

## Layout

```
lib/
├── design/        Theme tokens, colors, typography, spacing, radius
├── widgets/       Self-drawn UI primitives (no Material/Cupertino)
├── terminal/      xterm integration, Pane split tree, broadcast, search
├── system/        Cross-platform: clipboard, update, battery, network
├── features/      Business modules — UI-platform-agnostic portion
├── animations/    Curves and durations
├── shortcuts/     Keybinding registry
├── icons/         TermexIcons (Lucide aliasing)
├── layout/        Responsive layout helpers
└── l10n/          Generated localizations
```

## Consumer apps

| App | Pubspec entry |
|---|---|
| `termex/app` (desktop) | `termex_shared: { path: ../packages/termex_shared }` |
| `termex-mobile/app` | `termex_shared: { path: ../../termex/packages/termex_shared }` |

## What stays in each app's `lib/` (not in this package)

- `main.dart` — entry point (different shell choice per app)
- `desktop/` — desktop shell, sidebar, status bar (PC only)
- `mobile/` — mobile shell, bottom-bar, lifecycle (mobile only)
- `cross_tab/` — broadcast bus + cross-tab dialog (PC only)
- `features/auth/` — biometric unlock (mobile only)
- `features/.../mobile_*.dart` — per-feature mobile adapter sheets
- `features/team/qr_scanner_page.dart` — per-app concrete impl (PC stub vs mobile real)
- `src/frb_generated/` — FRB-generated bindings, anchored to `package:termex/...`

## Maintenance

- Any change to widgets/design/terminal/etc. lands in this package — automatically picked up by both apps on next `flutter pub get`.
- Import internally via relative paths (`../design/colors.dart`); consumer apps must import via `package:termex_shared/...`.
