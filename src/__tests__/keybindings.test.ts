import { describe, it, expect } from "vitest";
import {
  DEFAULT_KEYBINDINGS,
  KEYBINDING_ACTIONS,
  RESERVED_SHORTCUTS,
  formatKeybinding,
  keybindingEquals,
  isReserved,
  matchesEvent,
} from "@/types/keybindings";
import type { Keybinding, KeybindingAction } from "@/types/keybindings";

describe("Keybindings Types", () => {
  describe("DEFAULT_KEYBINDINGS", () => {
    it("has all 29 actions defined", () => {
      const actions = Object.keys(DEFAULT_KEYBINDINGS);
      expect(actions).toHaveLength(29);
    });

    it("includes v0.15.0 search actions", () => {
      expect(DEFAULT_KEYBINDINGS.search).toBeDefined();
      expect(DEFAULT_KEYBINDINGS.search.key).toBe("f");
      expect(DEFAULT_KEYBINDINGS.searchAllTabs).toBeDefined();
      expect(DEFAULT_KEYBINDINGS.searchAllTabs.key).toBe("f");
      expect(DEFAULT_KEYBINDINGS.searchAllTabs.shift).toBe(true);
    });

    it("all active bindings require mod key", () => {
      for (const [, binding] of Object.entries(DEFAULT_KEYBINDINGS)) {
        // Skip disabled bindings (empty key = unbound)
        if (!binding.key) continue;
        expect(binding.mod).toBe(true);
      }
    });

    it("goToTab1~9 map to keys 1~9", () => {
      for (let i = 1; i <= 9; i++) {
        const action = `goToTab${i}` as KeybindingAction;
        expect(DEFAULT_KEYBINDINGS[action].key).toBe(String(i));
      }
    });
  });

  describe("KEYBINDING_ACTIONS", () => {
    it("contains all 29 actions in order", () => {
      expect(KEYBINDING_ACTIONS).toHaveLength(29);
      expect(KEYBINDING_ACTIONS[0]).toBe("newConnection");
      expect(KEYBINDING_ACTIONS[KEYBINDING_ACTIONS.length - 1]).toBe("toggleBroadcast");
    });

    it("matches the keys in DEFAULT_KEYBINDINGS", () => {
      const defaultKeys = Object.keys(DEFAULT_KEYBINDINGS).sort();
      const actionKeys = [...KEYBINDING_ACTIONS].sort();
      expect(actionKeys).toEqual(defaultKeys);
    });
  });

  describe("keybindingEquals", () => {
    it("returns true for identical bindings", () => {
      const a: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const b: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      expect(keybindingEquals(a, b)).toBe(true);
    });

    it("returns true for case-insensitive key match", () => {
      const a: Keybinding = { mod: true, shift: true, alt: false, key: "I" };
      const b: Keybinding = { mod: true, shift: true, alt: false, key: "i" };
      expect(keybindingEquals(a, b)).toBe(true);
    });

    it("returns false when mod differs", () => {
      const a: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const b: Keybinding = { mod: false, shift: false, alt: false, key: "n" };
      expect(keybindingEquals(a, b)).toBe(false);
    });

    it("returns false when shift differs", () => {
      const a: Keybinding = { mod: true, shift: false, alt: false, key: "f" };
      const b: Keybinding = { mod: true, shift: true, alt: false, key: "f" };
      expect(keybindingEquals(a, b)).toBe(false);
    });

    it("returns false when key differs", () => {
      const a: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const b: Keybinding = { mod: true, shift: false, alt: false, key: "m" };
      expect(keybindingEquals(a, b)).toBe(false);
    });
  });

  describe("isReserved", () => {
    it("detects Cmd+C as reserved", () => {
      expect(isReserved({ mod: true, shift: false, alt: false, key: "c" })).toBe(true);
    });

    it("detects Cmd+V as reserved", () => {
      expect(isReserved({ mod: true, shift: false, alt: false, key: "v" })).toBe(true);
    });

    it("detects Cmd+A as reserved", () => {
      expect(isReserved({ mod: true, shift: false, alt: false, key: "a" })).toBe(true);
    });

    it("detects Cmd+Q as reserved", () => {
      expect(isReserved({ mod: true, shift: false, alt: false, key: "q" })).toBe(true);
    });

    it("does not flag Cmd+N as reserved", () => {
      expect(isReserved({ mod: true, shift: false, alt: false, key: "n" })).toBe(false);
    });

    it("does not flag Cmd+Shift+C as reserved (different modifiers)", () => {
      expect(isReserved({ mod: true, shift: true, alt: false, key: "c" })).toBe(false);
    });
  });

  describe("RESERVED_SHORTCUTS", () => {
    it("has 6 reserved shortcuts", () => {
      expect(RESERVED_SHORTCUTS).toHaveLength(6);
    });

    it("none of the default keybindings are reserved", () => {
      for (const binding of Object.values(DEFAULT_KEYBINDINGS)) {
        expect(isReserved(binding)).toBe(false);
      }
    });
  });

  describe("formatKeybinding", () => {
    it("formats a simple binding", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const result = formatKeybinding(binding);
      // Should contain either ⌘ (mac) or Ctrl (others) and N
      expect(result).toMatch(/N/);
      expect(result).toMatch(/⌘|Ctrl/);
    });

    it("includes shift modifier", () => {
      const binding: Keybinding = { mod: true, shift: true, alt: false, key: "f" };
      const result = formatKeybinding(binding);
      expect(result).toMatch(/⇧|Shift/);
    });

    it("includes alt modifier", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: true, key: "s" };
      const result = formatKeybinding(binding);
      expect(result).toMatch(/⌥|Alt/);
    });

    it("formats special keys", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: false, key: "Tab" };
      const result = formatKeybinding(binding);
      expect(result).toContain("Tab");
    });
  });

  describe("matchesEvent", () => {
    const isMac = typeof navigator !== "undefined" &&
      navigator.platform.toUpperCase().includes("MAC");

    /** Creates a mock event with the platform-correct mod key. */
    function mockEvent(overrides: Partial<KeyboardEvent> & { mod?: boolean }): KeyboardEvent {
      const { mod, ...rest } = overrides;
      return {
        key: "",
        ctrlKey: !isMac && (mod ?? false),
        metaKey: isMac && (mod ?? false),
        shiftKey: false,
        altKey: false,
        ...rest,
      } as KeyboardEvent;
    }

    it("matches mod+N binding", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const event = mockEvent({ key: "n", mod: true });
      expect(matchesEvent(event, binding)).toBe(true);
    });

    it("does not match without mod key", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const event = mockEvent({ key: "n" });
      expect(matchesEvent(event, binding)).toBe(false);
    });

    it("does not match wrong key", () => {
      const binding: Keybinding = { mod: true, shift: false, alt: false, key: "n" };
      const event = mockEvent({ key: "m", mod: true });
      expect(matchesEvent(event, binding)).toBe(false);
    });

    it("matches case-insensitively", () => {
      const binding: Keybinding = { mod: true, shift: true, alt: false, key: "I" };
      const event = mockEvent({ key: "I", mod: true, shiftKey: true });
      expect(matchesEvent(event, binding)).toBe(true);
    });

    it("requires shift when binding has shift", () => {
      const binding: Keybinding = { mod: true, shift: true, alt: false, key: "f" };
      const eventNoShift = mockEvent({ key: "f", mod: true });
      const eventWithShift = mockEvent({ key: "f", mod: true, shiftKey: true });
      expect(matchesEvent(eventNoShift, binding)).toBe(false);
      expect(matchesEvent(eventWithShift, binding)).toBe(true);
    });
  });
});
