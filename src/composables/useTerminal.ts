import { onUnmounted, ref, type Ref } from "vue";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebglAddon } from "@xterm/addon-webgl";
import { SearchAddon } from "@xterm/addon-search";
import "@xterm/xterm/css/xterm.css";
import { tauriInvoke, tauriListen } from "@/utils/tauri";
import { getTerminalTheme } from "@/utils/colors";
import { useSettingsStore } from "@/stores/settingsStore";
import { useSessionStore } from "@/stores/sessionStore";
import { buildFontFamilyCSS } from "@/utils/fontLoader";
import { registerTerminal, unregisterTerminal } from "@/utils/terminalRegistry";
import { useBroadcast } from "@/composables/useBroadcast";

/**
 * Composable that manages an xterm.js terminal instance
 * and bridges it with an SSH session via Tauri IPC.
 */
export interface TerminalOptions {
  /** Called after SSH shell is successfully opened. Use for tmux init, git sync, etc. */
  onShellReady?: (sessionId: string) => Promise<void>;
  /** Called when the connection is unexpectedly lost. Use for auto-reconnect. */
  onDisconnect?: (sessionId: string) => void;
  /** Autocomplete composable reference for keyboard shortcut integration. */
  getAutocomplete?: () => {
    suggestion: { value: string | null };
    popupVisible: { value: boolean };
    accept: () => void;
    dismiss: () => void;
    showPopup: () => void;
    nextSuggestion: () => void;
    prevSuggestion: () => void;
  } | null;
}

export function useTerminal(sessionId: Ref<string>, options?: TerminalOptions) {
  const terminalRef = ref<HTMLElement>();
  let terminal: Terminal | null = null;
  let fitAddon: FitAddon | null = null;
  let webglAddon: WebglAddon | null = null;
  let searchAddon: SearchAddon | null = null;
  let unlistenData: (() => void) | null = null;
  let unlistenStatus: (() => void) | null = null;
  let resizeObserver: ResizeObserver | null = null;

  /** Whether the remote application has enabled mouse reporting (e.g. zellij, tmux, vim). */
  const mouseReporting = ref(false);
  let lastModeCheck = 0;

  /**
   * Safe fit: uses getBoundingClientRect for accurate container measurement and
   * ensures the calculated rows never exceed what the visible area can display.
   * Falls back to FitAddon if internal dimensions aren't available yet.
   */
  function safeFit() {
    if (!terminal || !fitAddon) return;
    const el = terminal.element;
    if (!el || !el.parentElement) {
      fitAddon.fit();
      return;
    }
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const core = (terminal as any)._core;
    const dims = core?._renderService?.dimensions;
    if (!dims || dims.css.cell.width === 0 || dims.css.cell.height === 0) {
      fitAddon.fit();
      return;
    }

    const parentRect = el.parentElement.getBoundingClientRect();
    const style = window.getComputedStyle(el);
    const padTop = parseFloat(style.paddingTop) || 0;
    const padBot = parseFloat(style.paddingBottom) || 0;
    const padLeft = parseFloat(style.paddingLeft) || 0;
    const padRight = parseFloat(style.paddingRight) || 0;

    const scrollbarWidth = terminal.options.scrollback === 0
      ? 0 : (core.viewport?.scrollBarWidth ?? 0);

    const availH = parentRect.height - padTop - padBot;
    const availW = parentRect.width - padLeft - padRight - scrollbarWidth;

    const cols = Math.max(2, Math.floor(availW / dims.css.cell.width));
    const rows = Math.max(1, Math.floor(availH / dims.css.cell.height));

    if (terminal.rows !== rows || terminal.cols !== cols) {
      core._renderService.clear();
      terminal.resize(cols, rows);
    }
  }

  /** Mounts xterm.js into a DOM element and binds to the SSH session. */
  async function mount(el: HTMLElement) {
    const settingsStore = useSettingsStore();
    const sessionStore = useSessionStore();
    terminal = new Terminal({
      cursorBlink: settingsStore.cursorBlink,
      cursorStyle: settingsStore.cursorStyle,
      fontSize: settingsStore.fontSize,
      fontFamily: buildFontFamilyCSS(settingsStore.fontFamily),
      scrollback: settingsStore.scrollbackLines,
      theme: getTerminalTheme(),
      allowProposedApi: true,
      // Rescale glyphs wider than a single cell (Nerd Font icons, powerline symbols)
      rescaleOverlappingGlyphs: true,
      // Prevent bold text from shifting to bright ANSI colors
      drawBoldTextInBrightColors: false,
    });

    fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);

    searchAddon = new SearchAddon();
    terminal.loadAddon(searchAddon);

    terminal.open(el);

    // Try WebGL renderer, fall back to canvas.
    // Deferred via requestAnimationFrame to avoid M1 Metal backend initialization hang.
    requestAnimationFrame(() => {
      if (!terminal) return;
      try {
        webglAddon = new WebglAddon();
        terminal.loadAddon(webglAddon);
      } catch {
        webglAddon = null;
      }
      // Re-fit after renderer switch: WebGL cell dimensions may differ from DOM renderer,
      // which could cause rows to be slightly wrong, hiding the cursor at the bottom.
      safeFit();
    });

    // Copy/Paste keyboard support
    // - Mac: Cmd+C copies selection (falls through to terminal SIGINT if no selection)
    // - Linux: Ctrl+Shift+C copies selection
    // - Paste: Cmd+V (Mac) / Ctrl+Shift+V (Linux)
    terminal.attachCustomKeyEventHandler((ev) => {
      const isMac = navigator.platform.startsWith("Mac");
      if (ev.type !== "keydown") return true;

      // Skip all custom handling during IME composition (Chinese/Japanese/Korean input)
      if (ev.isComposing || ev.keyCode === 229) return true;

      // Copy: Cmd+C (Mac) or Ctrl+Shift+C (Linux)
      if (ev.key === "c" && ((isMac && ev.metaKey && !ev.shiftKey) || (!isMac && ev.ctrlKey && ev.shiftKey))) {
        const sel = terminal!.getSelection();
        if (sel) {
          navigator.clipboard.writeText(sel);
          return false; // prevent terminal from processing
        }
        // No selection on Mac Cmd+C → let through as SIGINT
        return isMac ? true : false;
      }

      // Paste: Cmd+V (Mac) or Ctrl+Shift+V (Linux)
      if (ev.key === "v" && ((isMac && ev.metaKey && !ev.shiftKey) || (!isMac && ev.ctrlKey && ev.shiftKey))) {
        ev.preventDefault();
        ev.stopPropagation();
        tauriInvoke<string>("clipboard_read_text").then((text) => {
          if (text && terminal) {
            terminal.paste(text);
          }
        });
        return false;
      }

      // === AI Autocomplete shortcuts ===
      const ac = options?.getAutocomplete?.();
      if (ac) {
        // Tab: accept ghost text (only when suggestion visible)
        if (ev.key === "Tab" && !ev.shiftKey && !ev.ctrlKey && !ev.metaKey && !ev.altKey) {
          if (ac.suggestion.value) {
            ev.preventDefault();
            ev.stopPropagation();
            ac.accept();
            return false;
          }
          return true; // No suggestion → pass Tab to shell for native completion
        }

        // Escape: dismiss suggestion/popup
        if (ev.key === "Escape") {
          if (ac.suggestion.value || ac.popupVisible.value) {
            ac.dismiss();
            return false;
          }
          return true;
        }

        // Ctrl+Space: show popup
        if (ev.key === " " && ev.ctrlKey && !ev.shiftKey && !ev.metaKey) {
          ac.showPopup();
          return false;
        }

        // Alt+]: next suggestion
        if (ev.key === "]" && ev.altKey) {
          ac.nextSuggestion();
          return false;
        }

        // Alt+[: previous suggestion
        if (ev.key === "[" && ev.altKey) {
          ac.prevSuggestion();
          return false;
        }
      }

      return true;
    });

    // OSC 52: remote clipboard write — used by zellij, tmux, vim, neovim, etc.
    // When the user copies text inside a remote multiplexer, it sends:
    //   ESC ] 52 ; c ; <base64-text> BEL
    // Without this handler the sequence is silently dropped and nothing is copied.
    terminal.parser.registerOscHandler(52, (data) => {
      const semi = data.indexOf(";");
      if (semi === -1) return false;
      const payload = data.slice(semi + 1);
      if (!payload || payload === "?") return false; // '?' = clipboard query, ignore
      try {
        const text = atob(payload);
        if (text) navigator.clipboard.writeText(text).catch(() => {});
        return true;
      } catch {
        return false;
      }
    });

    safeFit();
    terminal.focus();
    // Ensure focus after xterm fully renders
    requestAnimationFrame(() => terminal?.focus());

    // Bind data events BEFORE opening shell/PTY so no initial output is lost
    await bindSession();

    // Determine session type from store
    const session = sessionStore.sessions.get(sessionId.value);
    const sessionType = session?.type ?? (sessionId.value.startsWith("local-") ? "local" : "ssh");
    const { cols, rows } = terminal;

    // kube-logs: read-only terminal, no user input
    const isReadOnly = sessionType === "kube-logs";
    if (isReadOnly) {
      terminal.options.disableStdin = true;
      terminal.options.cursorBlink = false;
    }

    // Open the appropriate backend session
    try {
      if (sessionType === "local") {
        await tauriInvoke("local_pty_open", { sessionId: sessionId.value, cols, rows });
      } else if (sessionType === "kube-exec") {
        const meta = session?.cloudMeta;
        await tauriInvoke("cloud_kube_exec", {
          sessionId: sessionId.value,
          context: meta?.context ?? "",
          namespace: meta?.namespace ?? "",
          pod: meta?.pod ?? "",
          container: meta?.container ?? null,
          shell: null,
          cols,
          rows,
        });
        sessionStore.updateStatus(sessionId.value, "connected");
      } else if (sessionType === "ssm") {
        const meta = session?.cloudMeta;
        await tauriInvoke("cloud_ssm_connect", {
          sessionId: sessionId.value,
          instanceId: meta?.instanceId ?? "",
          profile: meta?.profile ?? null,
          region: meta?.region ?? null,
          cols,
          rows,
        });
        sessionStore.updateStatus(sessionId.value, "connected");
      } else if (sessionType === "kube-logs") {
        const meta = session?.cloudMeta;
        await tauriInvoke("cloud_kube_logs", {
          sessionId: sessionId.value,
          context: meta?.context ?? "",
          namespace: meta?.namespace ?? "",
          pod: meta?.pod ?? "",
          container: meta?.container ?? null,
          tailLines: 100,
          follow: true,
        });
      } else {
        // SSH
        await sessionStore.openShell(sessionId.value, cols, rows);
        if (options?.onShellReady) {
          await options.onShellReady(sessionId.value).catch(() => {});
        }
      }
    } catch (err) {
      terminal.write(`\r\n\x1b[31m[Error: ${err}]\x1b[0m\r\n`);
    }

    // User input → backend (skip for read-only sessions)
    if (!isReadOnly) {
      const isPty = sessionType === "local" || sessionType === "kube-exec" || sessionType === "ssm";
      const writeCmd = isPty ? "local_pty_write" : "ssh_write";
      const broadcast = useBroadcast();
      terminal.onData((data: string) => {
        if (sessionId.value) {
          const bytes = new TextEncoder().encode(data);
          tauriInvoke(writeCmd, {
            sessionId: sessionId.value,
            data: Array.from(bytes),
          }).catch(() => {});

          if (broadcast.isActive.value) {
            broadcast.broadcastInput(data);
          }
        }
      });
    }

    // Terminal resize → backend (skip for log streams)
    if (!isReadOnly) {
      const isPty = sessionType === "local" || sessionType === "kube-exec" || sessionType === "ssm";
      const resizeCmd = isPty ? "local_pty_resize" : "ssh_resize";
      terminal.onResize(({ cols, rows }) => {
        if (sessionId.value) {
          tauriInvoke(resizeCmd, {
            sessionId: sessionId.value,
            cols,
            rows,
          }).catch(() => {});
        }
      });
    }

    // Container resize → fit terminal (debounced to avoid v-show transition flicker)
    let resizeTimer: ReturnType<typeof setTimeout> | null = null;
    resizeObserver = new ResizeObserver((entries) => {
      const { width, height } = entries[0].contentRect;
      if (width > 0 && height > 0 && terminal) {
        if (resizeTimer) clearTimeout(resizeTimer);
        resizeTimer = setTimeout(() => safeFit(), 16);
      }
    });
    resizeObserver.observe(el);

    // Register terminal in global registry for cross-tab search
    registerTerminal(sessionId.value, terminal, searchAddon);
  }

  /** Binds Tauri event listeners for SSH data and status. */
  async function bindSession() {
    const sid = sessionId.value;
    if (!sid) return;

    // SSH data → terminal
    const unlisten1 = await tauriListen<number[]>(
      `ssh://data/${sid}`,
      (payload) => {
        if (terminal) {
          terminal.write(new Uint8Array(payload));
          // Throttled check: detect mouse reporting mode changes (zellij, tmux, vim, etc.)
          const now = Date.now();
          if (now - lastModeCheck > 1000) {
            lastModeCheck = now;
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            const mode = (terminal as any).modes?.mouseTrackingMode ?? "none";
            const isActive = mode !== "none";
            if (isActive !== mouseReporting.value) {
              mouseReporting.value = isActive;
            }
          }
        }
      },
    );
    unlistenData = unlisten1;

    // SSH status events
    const sessionStore = useSessionStore();
    const unlisten2 = await tauriListen<{ status: string; message: string }>(
      `ssh://status/${sid}`,
      (payload) => {
        if (
          terminal &&
          (payload.status === "disconnected" || payload.status === "exited")
        ) {
          terminal.write(`\r\n\x1b[33m[${payload.message}]\x1b[0m\r\n`);
          sessionStore.updateStatus(sid, "disconnected");
          options?.onDisconnect?.(sid);
        }
      },
    );
    unlistenStatus = unlisten2;
  }

  /** Rebinds event listeners to a new session ID without destroying the terminal.
   *  Used for reconnection: the xterm instance and scrollback are preserved. */
  async function rebindSession(oldSessionId: string, newSessionId: string) {
    unlistenData?.();
    unlistenStatus?.();
    unlistenData = null;
    unlistenStatus = null;

    unregisterTerminal(oldSessionId);
    if (terminal && searchAddon) {
      registerTerminal(newSessionId, terminal, searchAddon);
    }

    // bindSession reads sessionId.value which should already be updated to newSessionId
    await bindSession();
  }

  /** Returns the current terminal dimensions. */
  function getDimensions(): { cols: number; rows: number } {
    if (terminal) {
      return { cols: terminal.cols, rows: terminal.rows };
    }
    return { cols: 80, rows: 24 };
  }

  /** Triggers a fit recalculation and focuses the terminal.
   *  Recreates WebGL addon to recover from display:none context loss. */
  function fit() {
    if (!terminal || !fitAddon) return;

    // WebGL context is lost when element is display:none (v-show hidden).
    // Recreate it before fitting to avoid rendering glitches.
    if (webglAddon) {
      try {
        webglAddon.dispose();
      } catch { /* already disposed */ }
      webglAddon = null;
    }
    try {
      webglAddon = new WebglAddon();
      terminal.loadAddon(webglAddon);
    } catch {
      webglAddon = null;
    }

    safeFit();
    terminal.focus();
  }

  /** Updates the terminal theme. */
  function setTheme() {
    if (terminal) {
      terminal.options.theme = getTerminalTheme();
    }
  }

  /** Updates the terminal font family and size. */
  function setFont(family: string, size: number) {
    if (!terminal) return;
    terminal.options.fontFamily = buildFontFamilyCSS(family);
    terminal.options.fontSize = size;

    // WebGL addon caches a font texture atlas — must recreate it after font change
    if (webglAddon) {
      webglAddon.dispose();
      webglAddon = null;
      try {
        webglAddon = new WebglAddon();
        terminal.loadAddon(webglAddon);
      } catch {
        webglAddon = null;
      }
    }

    safeFit();
  }

  /** Returns the underlying Terminal instance (for search / highlight). */
  function getTerminal(): Terminal | null {
    return terminal;
  }

  /** Returns the SearchAddon instance. */
  function getSearchAddon(): SearchAddon | null {
    return searchAddon;
  }

  /** Cleans up all resources. */
  function dispose() {
    unregisterTerminal(sessionId.value);
    unlistenData?.();
    unlistenStatus?.();
    resizeObserver?.disconnect();
    webglAddon?.dispose();
    searchAddon?.dispose();
    fitAddon?.dispose();
    terminal?.dispose();
    terminal = null;
    fitAddon = null;
    webglAddon = null;
    searchAddon = null;
    unlistenData = null;
    unlistenStatus = null;
    resizeObserver = null;
  }

  onUnmounted(dispose);

  return { terminalRef, mount, getDimensions, fit, setTheme, setFont, getTerminal, getSearchAddon, rebindSession, dispose, mouseReporting };
}
