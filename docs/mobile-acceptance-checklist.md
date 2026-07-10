# Mobile Acceptance Checklist (v0.77.0 → v0.79.5)

> Status: ready for user validation
> Last updated: 2026-05-25
> Scope: end-to-end manual checks for iOS + Android + iPad after 13 mobile
> iterations. Cross off as you go; everything below is what the automated
> build + widget tests can't reach without a real SSH server and human eyes.

This checklist follows the same order a fresh user would experience the
app. Items prefixed `[A]` are Android-only, `[I]` are iOS-only, `[T]`
are iPad/tablet-only, unmarked items apply to all three.

---

## 1. Cold-start chrome

System bars, fonts, splash — verifies v0.77.0 / v0.79.2 work.

- [ ] App icon visible on the launcher / home screen (default Flutter
      icon for now — Termex brand icon pending v0.79.6)
- [ ] Tap icon, **splash screen is dark** (no white flash) — v0.79.2
- [ ] Status bar is **transparent + white icons** over the dark
      background — v0.79.2
- [ ] **No system-default "light mode" leakage** even if the OS is
      configured for Light mode — v0.79.2
- [ ] [A] Bottom navigation bar (gesture pill) blends into dark theme
- [ ] [I] Home indicator pill visible but subtle

## 2. MobileShell — BottomBar (iPhone / Android phone)

Verifies v0.77.1 / v0.78.0.

- [ ] BottomBar shows 4 tabs: Terminal / Files / AI / Settings
- [ ] Terminal tab is selected on first launch (blue T)
- [ ] Tap each tab → content area swaps correctly
- [ ] Tab switches retain server-list state (Riverpod)
- [ ] Safe-area inset respected (no content under status / nav bars)

## 3. NavRail (iPad)

Verifies v0.79.1.

- [T] On iPad portrait: width ≥ 900, **left vertical NavRail** (80px)
      with same 4 tabs (T / F / A / S)
- [T] No BottomBar at the bottom
- [T] Detail pane on the right shows current tab's content
- [T] Rotate iPad to landscape — layout preserved (still NavRail)

## 4. Server add flow

Verifies v0.77.1 ServerFormDialog wiring.

- [ ] Tap the blue "+" in the Terminal tab header
- [ ] ServerFormDialog opens (dark themed, NOT system light)
- [ ] Fields: name, host, port (default 22), username, auth type
      (password / key / agent / interactive), password / key path
- [ ] Save → new server tile appears in the list
- [ ] List tile shows: name + `username@host:port`

## 5. SSH connection — terminal

Verifies the core flow, including v0.77.1 xterm + v0.79.3 fg service.

> Prereq: have a real remote SSH server reachable (Docker / Linux VPS).

- [ ] Tap the saved server tile
- [ ] MobileTerminalPage opens with "Connecting…" status
- [ ] After 1-3s: shell prompt visible (welcome banner / `$ ` prompt)
- [ ] Type `uname -a` + Enter → output appears
- [ ] Type `ls /tmp` → directory listing renders, ANSI colors render
- [ ] Long lines wrap correctly
- [ ] Scrollback works (swipe up to view earlier output)
- [ ] [A] **Status bar now shows the "Termex — 1 active session"
      foreground notification** — v0.79.3
- [ ] [I] No iOS background indicator (none expected)

## 6. Soft keyboard toolbar (terminal)

Verifies v0.77.2 / v0.78.2 / v0.79.1.

- [ ] Tap into terminal → iOS / Android soft keyboard opens
- [ ] Toolbar above the keyboard with 16 buttons:
      `Ctrl | Esc | Tab | ^C | ^D | ^Z | ↑ | ↓ | ← | → | PgUp | PgDn |
      Home | End | Del | Ins`
- [ ] Toolbar **scrolls horizontally** (more buttons than screen width)
- [ ] **Esc** → fires escape (works in `vi` insert mode)
- [ ] **Tab** → tab completion in shell works (start typing a path,
      tap Tab)
- [ ] **^C** → interrupts a running command (`sleep 60` → tap ^C →
      shell returns to prompt)
- [ ] **^D** → EOF (in shell, exits)
- [ ] **↑ ↓** → command history scrolls
- [ ] **← →** → cursor moves within the current command
- [ ] **PgUp / PgDn / Home / End** → work in `less` / `vi`
- [ ] **Sticky Ctrl**:
      1. Tap `Ctrl` button — it stays highlighted (blue background)
      2. Type a letter via soft keyboard, e.g. `l`
      3. Should emit `Ctrl-L` (clear screen)
      4. Highlight auto-releases after one letter

## 7. Pinch-to-zoom (terminal)

Verifies v0.79.1.

- [ ] Two-finger pinch out → font size grows
- [ ] Two-finger pinch in → font size shrinks
- [ ] Range bounded: 8px (smallest) to 28px (largest)
- [ ] Single-finger tap / scroll still works (no gesture conflict)
- [ ] Font change is smooth, no flicker

## 8. SFTP file browser

Verifies v0.78.0 / v0.78.1.

- [ ] Tap BottomBar **Files** → server list with "Files" header
- [ ] Tap a server → MobileSftpPage opens with "Opening SFTP channel…"
- [ ] Directory listing renders (large 44pt rows on mobile, dense 28pt
      on iPad)
- [ ] On mobile: only name + size visible (no date / permissions column
      — they're hidden to save width per v0.78.1)
- [ ] On iPad: full columns visible
- [ ] Tap a directory → navigates into it
- [ ] Path bar at top shows current path

## 9. AI panel

Verifies v0.78.0 / v0.78.1.

- [ ] Tap BottomBar **AI**
- [ ] On mobile (< 600px): **conversation sidebar hidden by default**
      — v0.78.1
- [ ] On iPad / tablet: sidebar visible
- [ ] Manual toggle button works (top-left icon)
- [ ] Toggle preference sticks during the session

## 10. Settings → Background keep-alive section

Verifies v0.79.5.

- [ ] Tap BottomBar **Settings**
- [ ] Top of page: card titled "Background keep-alive"
- [ ] [A] Card explains foreground service + manufacturer caveat
- [ ] [A] Row "Battery optimisation: Standard (may be killed)" in pink
- [ ] [A] Tap "Open system settings" button → system dialog appears
      asking to whitelist Termex
- [ ] [A] Tap "Allow" → return to Termex → row updates to "Whitelisted"
      in green
- [ ] [I] Card explains 30-second iOS limit (no buttons)
- [ ] Below this card: standard SettingsPage tabs (appearance,
      terminal, AI, etc.)

## 11. Background keep-alive — real behaviour

> The actual point of v0.79.3 / v0.79.4 / v0.79.5. Needs an active SSH
> session and a stopwatch.

- [ ] Open a server in MobileTerminalPage, get a shell prompt
- [ ] [A] Press HOME (go to launcher)
- [ ] [A] Wait 1 minute
- [ ] [A] Foreground notification still visible
- [ ] [A] Open Termex via notification → session reconnects /
      preserved scrollback
- [ ] [A] Repeat after **5 minutes** — same result expected (this is
      where un-whitelisted OEM phones may break; this is exactly why
      we surface battery-optimisation status in Settings)
- [ ] [I] Press HOME on iPhone
- [ ] [I] Wait **30 seconds**
- [ ] [I] Open Termex from app switcher — session may have been
      torn down (expected on iOS per platform constraints)
- [ ] [I] Wait several hours, return to Termex — BGAppRefreshTask
      *may* have kept the process warm (best-effort, not guaranteed)

## 12. Disconnection / close

- [ ] In MobileTerminalPage, tap the X close button (top-left)
- [ ] Returns to server list
- [ ] [A] Foreground notification disappears within ~1s
- [ ] [I] No visible change (no notification existed)
- [ ] Tap the same server again → fresh new connection works

## 13. Multi-session

- [ ] From server list, open server A → terminal
- [ ] Close back to server list
- [ ] Open server B → terminal
- [ ] Each session is independent (no output crosstalk)
- [ ] [A] Foreground notification text counts active sessions correctly
      (open 2 simultaneously via separate routes if possible)

## 14. App lifecycle

- [ ] Force-kill app from recent-tasks switcher
- [ ] Reopen → returns to first launch state (Terminal tab)
- [ ] [A] Foreground notification gone, service stopped
- [ ] No stale SSH connections from before the kill (server-side ssh
      auth log shows clean disconnect)
- [ ] Saved servers + master-password state survive kill

## 15. Cross-platform sanity

- [ ] iPhone → iPad (same Apple ID): app appears on iPad
- [ ] [T] All tabs work on iPad
- [ ] Switch between portrait / landscape multiple times — no layout
      lockup

---

## How to report findings

For each ❌ item, please capture:
1. Device model + OS version (e.g. "Pixel 9, Android 15")
2. App version (Settings → About if available, else commit SHA)
3. Steps to reproduce
4. Expected vs. actual (one sentence each)
5. Screenshot / screen recording if applicable

Per v0.79.x cycle, save reports under `docs/iterations/` as
`v0.79.x-acceptance-feedback.md`. Items get triaged into the next
iteration's backlog.

## Coverage notes

Some items are *intentionally* not auto-testable from the host machine:

- Pinch-to-zoom requires multi-touch input that the iOS / Android
  simulators don't reliably emit via `simctl` / `adb shell input`.
- SSH connection requires a real network destination; the iOS
  simulator and Android emulator on host can both reach the public
  internet, so this is feasible in practice but server-side log
  inspection is more efficient than parsing client output.
- BGAppRefreshTask actual firing on iOS depends on the OS's
  scheduler and only manifests on **physical devices over the course
  of hours / days**. Simulator never fires it spontaneously.
- iOS keychain single-prompt behaviour differs between simulator
  (kSecAttrAccessibleAfterFirstUnlock semantics relaxed) and device;
  always cross-check on a physical iPhone before release.

For everything else, refer to:
- `flutter test test/mobile/` — 7 widget + unit tests (v0.77.1+)
- `cargo test --workspace` — 14+ Rust tests
- `flutter build {ios,apk,macos} --debug` — three build smokes
- CI workflow `.github/workflows/ci.yml` — `ios-bootstrap-check` +
  `android-bootstrap-check` jobs guard the toolchain
