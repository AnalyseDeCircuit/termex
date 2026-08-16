import { tauriInvoke } from "@/utils/tauri";

/**
 * Decode an OSC 52 base64 payload as UTF-8.
 *
 * `atob` yields one character per *byte*, so any multi-byte text — CJK,
 * accents, emoji — arrived mangled. Re-interpreting those bytes through
 * TextDecoder restores the original string (issue #19).
 */
export function decodeBase64Utf8(payload: string): string {
  const binary = atob(payload);
  const bytes = Uint8Array.from(binary, (ch) => ch.charCodeAt(0));
  return new TextDecoder("utf-8").decode(bytes);
}

/**
 * Copy text to the system clipboard.
 *
 * Prefers the native backend: `navigator.clipboard.writeText` is rejected when
 * the caller is not inside a user-gesture handler, which is exactly the case
 * for OSC 52 sequences arriving from a remote program, and the failure is
 * silent. Falls back to the web API if the command is unavailable.
 */
export async function writeClipboard(text: string): Promise<void> {
  try {
    await tauriInvoke("clipboard_write_text", { text });
  } catch {
    await navigator.clipboard.writeText(text).catch(() => {});
  }
}
