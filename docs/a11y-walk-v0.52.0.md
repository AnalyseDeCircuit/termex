# v0.52.0 Accessibility Walk Checklist

> Operator-facing checklist for §C4 of [v0.52.0-gap-coverage.md](iterations/v0.52.0-gap-coverage.md).
> Automated coverage in `app/integration_test/accessibility_flow_test.dart` (Semantics assertions) is complementary; this checklist validates real AT navigation.

## Scope

Three golden paths × three screen readers, ~30 minutes per platform.

### Golden paths

1. **New server**: App launch → "New Server" → fill form → save → see in tree
2. **SSH login**: Select server → connect → type in terminal → disconnect
3. **AI dialog**: Open AI panel → type question → read streaming reply → copy command

### Screen readers

| Platform | AT | Launch |
|---|---|---|
| macOS | VoiceOver | `Cmd + F5` |
| Windows | NVDA | `Ctrl + Alt + N` (after install) |
| Linux (GNOME) | Orca | `Super + Alt + S` |

## Pre-walk setup

```bash
cd /Users/liuyidao/Documents/huzou/termex/app
flutter build macos --release --dart-define=SENTINEL=false
open build/macos/Build/Products/Release/Termex.app
```

(Equivalent `flutter build windows --release` / `flutter build linux --release` on other platforms.)

## Walk script

For each screen reader:

### Path 1 — New server

- [ ] App launch announcement reads "Termex" or app title (not "Flutter app")
- [ ] Focus lands on something sensible (search bar or server tree root)
- [ ] `Tab` moves focus through: menu bar → sidebar → main pane (no focus loss)
- [ ] "New Server" button announces its role + label (`button`, "New Server")
- [ ] Server form: each input announces its label, type, and current value
- [ ] Required fields announce required state
- [ ] Validation errors announce as they appear (live region)
- [ ] "Save" button is reachable via Tab; announces success after activation
- [ ] Newly created server is announced in tree (focus or live region)

### Path 2 — SSH login

- [ ] Activating a server announces connection progress
- [ ] Terminal pane announces role (`terminal` or `text input`)
- [ ] Typed characters are NOT echoed by the AT for password prompts (redaction)
- [ ] Connected indicator changes are announced (status live region)
- [ ] Disconnect button reachable via keyboard

### Path 3 — AI dialog

- [ ] AI panel opens with focus inside the input
- [ ] Streaming reply: AT announces incremental chunks (or has a "done" announcement on finish — either pattern is acceptable)
- [ ] Code blocks announce their role (`code` or `region, code`)
- [ ] "Copy" button reachable and announces "Copied to clipboard"
- [ ] "Insert into terminal" announces the action

## Severity thresholds

| Severity | Examples | Action |
|---|---|---|
| **Critical** | Path cannot be completed with AT alone; focus traps; unlabeled submit button | Block v0.52.0 release until fixed |
| **Major** | Announcements missing for state changes; wrong role; keyboard-only user must fall back to mouse | Fix within the v0.52.0 window |
| **Minor** | Announcement redundancy; ordering quirk | Track, fix in v0.53 |

## Reporting

Record findings in this doc under the "Results" section below. Per platform / per path, note: pass / fail + severity + short reproduction.

## Results

### macOS / VoiceOver (2026-XX-XX, OS 15.x)

- Path 1: _not yet walked_
- Path 2: _not yet walked_
- Path 3: _not yet walked_

### Windows / NVDA (2026-XX-XX, NVDA 2025.x)

- Path 1: _not yet walked_
- Path 2: _not yet walked_
- Path 3: _not yet walked_

### Linux / Orca (2026-XX-XX, GNOME 47)

- Path 1: _not yet walked_
- Path 2: _not yet walked_
- Path 3: _not yet walked_

## Automation pointer

`app/integration_test/accessibility_flow_test.dart` asserts Semantics trees for the same three paths. Walk findings should feed back into that file as new Semantics assertions to prevent regression.
