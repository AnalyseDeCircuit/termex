/** All bindable action identifiers. */
export type KeybindingAction =
  | "newConnection"
  | "openSettings"
  | "toggleSidebar"
  | "toggleAi"
  | "closeTab"
  | "nextTab"
  | "prevTab"
  | "search"
  | "searchAllTabs"
  | "goToTab1"
  | "goToTab2"
  | "goToTab3"
  | "goToTab4"
  | "goToTab5"
  | "goToTab6"
  | "goToTab7"
  | "goToTab8"
  | "goToTab9"
  | "toggleMonitor"
  | "splitVertical"
  | "splitHorizontal"
  | "closePaneOrTab"
  | "focusPaneNext"
  | "focusPanePrev"
  | "focusPaneUp"
  | "focusPaneDown"
  | "focusPaneLeft"
  | "focusPaneRight"
  | "toggleBroadcast";

/** A keyboard shortcut composed of modifier keys + a main key. */
export interface Keybinding {
  /** Platform-adaptive modifier: metaKey on macOS, ctrlKey on others. */
  mod: boolean;
  shift: boolean;
  alt: boolean;
  /** Ctrl key on macOS (independent of mod/Cmd). Ignored on Windows/Linux where mod IS ctrl. */
  ctrl?: boolean;
  /** The primary key (KeyboardEvent.key value, e.g., "n", "Tab", "1"). */
  key: string;
}

/** Map from action ID to its keybinding. */
export type KeybindingMap = Record<KeybindingAction, Keybinding>;

/** Ordered list of actions for UI display (goToTab collapsed into one row by default). */
export const KEYBINDING_ACTIONS: KeybindingAction[] = [
  "newConnection",
  "openSettings",
  "toggleSidebar",
  "toggleAi",
  "closeTab",
  "nextTab",
  "prevTab",
  "search",
  "searchAllTabs",
  "goToTab1",
  "goToTab2",
  "goToTab3",
  "goToTab4",
  "goToTab5",
  "goToTab6",
  "goToTab7",
  "goToTab8",
  "goToTab9",
  "toggleMonitor",
  "splitVertical",
  "splitHorizontal",
  "closePaneOrTab",
  "focusPaneNext",
  "focusPanePrev",
  "focusPaneUp",
  "focusPaneDown",
  "focusPaneLeft",
  "focusPaneRight",
  "toggleBroadcast",
];

/** Default keybinding mapping. */
export const DEFAULT_KEYBINDINGS: KeybindingMap = {
  newConnection:  { mod: true, shift: false, alt: false, key: "n" },
  openSettings:   { mod: true, shift: false, alt: false, key: "," },
  toggleSidebar:  { mod: true, shift: false, alt: false, key: "\\" },
  toggleAi:       { mod: true, shift: true,  alt: false, key: "I" },
  closeTab:       { mod: false, shift: false, alt: false, key: "" },
  nextTab:        { mod: true, shift: false, alt: false, key: "Tab" },
  prevTab:        { mod: true, shift: true,  alt: false, key: "Tab" },
  search:         { mod: true, shift: false, alt: false, key: "f" },
  searchAllTabs:  { mod: true, shift: true,  alt: false, key: "f" },
  goToTab1:       { mod: true, shift: false, alt: false, key: "1" },
  goToTab2:       { mod: true, shift: false, alt: false, key: "2" },
  goToTab3:       { mod: true, shift: false, alt: false, key: "3" },
  goToTab4:       { mod: true, shift: false, alt: false, key: "4" },
  goToTab5:       { mod: true, shift: false, alt: false, key: "5" },
  goToTab6:       { mod: true, shift: false, alt: false, key: "6" },
  goToTab7:       { mod: true, shift: false, alt: false, key: "7" },
  goToTab8:       { mod: true, shift: false, alt: false, key: "8" },
  goToTab9:       { mod: true, shift: false, alt: false, key: "9" },
  toggleMonitor:  { mod: true, shift: true,  alt: false, key: "m" },
  splitVertical:    { mod: true, shift: false, alt: false, key: "d" },
  splitHorizontal:  { mod: true, shift: true,  alt: false, key: "D" },
  closePaneOrTab:   { mod: true, shift: false, alt: false, key: "w" },
  focusPaneNext:    { mod: true, shift: false, alt: false, key: "]" },
  focusPanePrev:    { mod: true, shift: false, alt: false, key: "[" },
  focusPaneUp:      { mod: true, shift: false, alt: true,  key: "ArrowUp" },
  focusPaneDown:    { mod: true, shift: false, alt: true,  key: "ArrowDown" },
  focusPaneLeft:    { mod: true, shift: false, alt: true,  key: "ArrowLeft" },
  focusPaneRight:   { mod: true, shift: false, alt: true,  key: "ArrowRight" },
  toggleBroadcast:  { mod: true, shift: true,  alt: false, key: "B" },
};

/** System-reserved shortcuts that cannot be rebound. */
export const RESERVED_SHORTCUTS: Keybinding[] = [
  { mod: true, shift: false, alt: false, key: "c" },  // Copy
  { mod: true, shift: false, alt: false, key: "v" },  // Paste
  { mod: true, shift: false, alt: false, key: "x" },  // Cut
  { mod: true, shift: false, alt: false, key: "a" },  // Select All
  { mod: true, shift: false, alt: false, key: "z" },  // Undo
  { mod: true, shift: false, alt: false, key: "q" },  // Quit (macOS)
];

const IS_MAC = typeof navigator !== "undefined" &&
  navigator.platform.toUpperCase().includes("MAC");

/** Formats a key name for display. */
function formatKeyName(key: string): string {
  const map: Record<string, string> = {
    Tab: "Tab",
    Enter: IS_MAC ? "↵" : "Enter",
    Backspace: IS_MAC ? "⌫" : "Backspace",
    Delete: IS_MAC ? "⌦" : "Delete",
    " ": "Space",
    ArrowUp: "↑",
    ArrowDown: "↓",
    ArrowLeft: "←",
    ArrowRight: "→",
    Escape: "Esc",
    "\\": "\\",
    ",": ",",
  };
  return map[key] ?? key.toUpperCase();
}

/** Formats a keybinding for display (e.g., "⌘ N" on macOS, "Ctrl+N" on others). */
export function formatKeybinding(binding: Keybinding): string {
  const parts: string[] = [];
  if (binding.ctrl && IS_MAC) parts.push("⌃");
  if (binding.mod) parts.push(IS_MAC ? "⌘" : "Ctrl");
  if (binding.shift) parts.push(IS_MAC ? "⇧" : "Shift");
  if (binding.alt) parts.push(IS_MAC ? "⌥" : "Alt");
  parts.push(formatKeyName(binding.key));
  return parts.join(IS_MAC ? " " : "+");
}

/** Compares two keybindings for equality. */
export function keybindingEquals(a: Keybinding, b: Keybinding): boolean {
  return (
    a.mod === b.mod &&
    a.shift === b.shift &&
    a.alt === b.alt &&
    (a.ctrl ?? false) === (b.ctrl ?? false) &&
    a.key.toLowerCase() === b.key.toLowerCase()
  );
}

/** Checks if a keybinding is system-reserved. */
export function isReserved(binding: Keybinding): boolean {
  return RESERVED_SHORTCUTS.some((r) => keybindingEquals(r, binding));
}

/** Checks if a keybinding matches a KeyboardEvent. */
export function matchesEvent(e: KeyboardEvent, binding: Keybinding): boolean {
  const mod = IS_MAC ? e.metaKey : e.ctrlKey;
  if (mod !== binding.mod) return false;
  if (e.shiftKey !== binding.shift) return false;
  if (e.altKey !== binding.alt) return false;

  // On macOS, check ctrl independently (for goToTab ctrl+1~9 support)
  if (IS_MAC && (binding.ctrl ?? false) !== e.ctrlKey) return false;

  // Primary: match by e.key (case-insensitive)
  const bindingKey = binding.key.toLowerCase();
  if (e.key.toLowerCase() === bindingKey) return true;

  // Fallback: match by e.code for cases where modifiers mangle e.key
  // (e.g., Shift+1 → "!", Control+2 → "\x00" on macOS)
  if (e.code) {
    // Digit keys: "Digit1" → "1"
    if (e.code.startsWith("Digit") && e.code.slice(5) === binding.key) return true;
    // Letter keys: "KeyN" → "n"
    if (e.code.startsWith("Key") && e.code.slice(3).toLowerCase() === bindingKey) return true;
  }

  return false;
}
