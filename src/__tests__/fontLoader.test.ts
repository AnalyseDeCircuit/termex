import { describe, it, expect, vi } from "vitest";

vi.mock("@/utils/tauri", () => ({ tauriInvoke: vi.fn() }));

const { buildFontFamilyCSS } = await import("@/utils/fontLoader");

/** Families a Nerd Font glyph can fall through to, per fontLoader. */
const SYMBOL_FALLBACK = "Symbols Nerd Font Mono";

describe("buildFontFamilyCSS", () => {
  it("puts the requested family first", () => {
    expect(buildFontFamilyCSS("Menlo").startsWith("'Menlo',")).toBe(true);
  });

  it("always ends with the generic monospace family", () => {
    expect(buildFontFamilyCSS("Menlo").endsWith(", monospace")).toBe(true);
  });

  // Issue #17: the abbreviated Nerd Font names are the ones the project
  // actually ships, and none of them match /nerd\s*font/.
  it.each([
    "MesloLGS NF",
    "FiraCode NFM",
    "JetBrainsMono NFP",
    "Hack Nerd Font",
    "Hack Nerd Font Mono",
  ])("supplies the symbol fallback for %s", (name) => {
    expect(buildFontFamilyCSS(name)).toContain(`'${SYMBOL_FALLBACK}'`);
  });

  it("supplies the symbol fallback for plain fonts too, without displacing them", () => {
    const css = buildFontFamilyCSS("Menlo");
    expect(css).toContain(`'${SYMBOL_FALLBACK}'`);
    expect(css.indexOf("'Menlo'")).toBeLessThan(css.indexOf(SYMBOL_FALLBACK));
  });

  it("does not list the symbol font twice when it is the chosen family", () => {
    const css = buildFontFamilyCSS(SYMBOL_FALLBACK);
    expect(css.match(new RegExp(SYMBOL_FALLBACK, "g"))).toHaveLength(1);
  });

  it("escapes quotes so a font name cannot break out of the CSS string", () => {
    expect(buildFontFamilyCSS("Ev'il")).toContain("'Ev\\'il'");
  });
});
