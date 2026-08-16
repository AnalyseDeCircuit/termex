import type { CustomFont } from "@/types/fonts";
import { tauriInvoke } from "@/utils/tauri";

/** Track loaded custom font faces for cleanup. */
const loadedFonts = new Map<string, FontFace>();

/**
 * Load a custom font via the FontFace API.
 * Reads font bytes from backend to avoid Tauri CSP restrictions on file:// URLs.
 *
 * The raw ArrayBuffer is handed to FontFace directly rather than wrapped in a
 * Blob URL: uploads accept .ttf/.otf/.woff/.woff2, and a hardcoded Blob MIME
 * made WKWebView (macOS) reject non-woff2 uploads. Passing binary data also
 * avoids leaking an object URL per font.
 */
export async function loadCustomFont(font: CustomFont): Promise<void> {
  if (loadedFonts.has(font.name)) return;

  try {
    const data = await tauriInvoke<number[]>("fonts_read", {
      fileName: font.fileName,
    });
    const face = new FontFace(font.name, new Uint8Array(data).buffer);
    await face.load();
    document.fonts.add(face);
    loadedFonts.set(font.name, face);
  } catch (err) {
    console.warn(`Failed to load custom font "${font.name}":`, err);
  }
}

/** Unload a custom font from document.fonts. */
export function unloadCustomFont(fontName: string): void {
  const face = loadedFonts.get(fontName);
  if (face) {
    document.fonts.delete(face);
    loadedFonts.delete(fontName);
  }
}

/** Load all custom fonts. Called on app startup and after upload. */
export async function loadAllCustomFonts(
  fonts: CustomFont[],
): Promise<void> {
  await Promise.allSettled(fonts.map((f) => loadCustomFont(f)));
}

/** Symbol-only fonts shipped by the Nerd Fonts project, in fallback order.
 *  Names differ per release/platform, so all known spellings are listed. */
const NERD_SYMBOL_FALLBACKS = [
  "Symbols Nerd Font Mono",
  "Symbols Nerd Font",
  "SymbolsNerdFontMono-Regular",
];

/** Escape a font family name for safe embedding in a quoted CSS ident. */
function quoteFamily(name: string): string {
  return `'${name.replace(/\\/g, "\\\\").replace(/'/g, "\\'")}'`;
}

/** Build CSS font-family string for xterm.js from a font name.
 *
 *  The Nerd Font symbol fonts are appended unconditionally. CSS only consults a
 *  fallback for codepoints the primary family does not cover, so this never
 *  overrides a font that already carries its own glyphs, and it is inert when
 *  the symbol fonts are not installed.
 *
 *  Detecting Nerd Fonts by name was the previous behaviour and did not work:
 *  the project's own patched fonts ship as "MesloLGS NF", "FiraCode NFM",
 *  "JetBrainsMono NFP" etc., none of which match /nerd\s*font/, so powerline
 *  and icon glyphs fell through to tofu (issue #17). */
export function buildFontFamilyCSS(fontName: string): string {
  const primary = quoteFamily(fontName);
  const fallbacks = NERD_SYMBOL_FALLBACKS.filter(
    (f) => f.toLowerCase() !== fontName.trim().toLowerCase(),
  ).map(quoteFamily);
  return [primary, ...fallbacks, "monospace"].join(", ");
}
