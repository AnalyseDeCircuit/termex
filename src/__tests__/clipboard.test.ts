import { describe, it, expect, vi, beforeEach } from "vitest";

const tauriInvoke = vi.fn();
vi.mock("@/utils/tauri", () => ({ tauriInvoke: (...a: unknown[]) => tauriInvoke(...a) }));

const { decodeBase64Utf8, writeClipboard } = await import("@/utils/clipboard");

/** Encode a string the way a remote program emitting OSC 52 would. */
function toBase64Utf8(text: string): string {
  const bytes = new TextEncoder().encode(text);
  return btoa(String.fromCharCode(...bytes));
}

describe("decodeBase64Utf8", () => {
  it("round-trips ASCII", () => {
    expect(decodeBase64Utf8(toBase64Utf8("hello world"))).toBe("hello world");
  });

  // Issue #19: atob() decodes per byte, so multi-byte text came back mangled.
  it.each(["中文复制测试", "café", "🚀 ship it", "日本語テキスト"])(
    "round-trips multi-byte text: %s",
    (text) => {
      expect(decodeBase64Utf8(toBase64Utf8(text))).toBe(text);
    },
  );

  it("differs from a naive atob for multi-byte input", () => {
    const payload = toBase64Utf8("中文");
    expect(decodeBase64Utf8(payload)).not.toBe(atob(payload));
  });

  it("returns empty string for empty payload", () => {
    expect(decodeBase64Utf8("")).toBe("");
  });
});

describe("writeClipboard", () => {
  beforeEach(() => {
    tauriInvoke.mockReset();
  });

  it("copies through the native backend", async () => {
    tauriInvoke.mockResolvedValue(undefined);
    await writeClipboard("payload");
    expect(tauriInvoke).toHaveBeenCalledWith("clipboard_write_text", {
      text: "payload",
    });
  });

  it("falls back to the web API when the command is unavailable", async () => {
    tauriInvoke.mockRejectedValue(new Error("no such command"));
    const writeText = vi.fn().mockResolvedValue(undefined);
    vi.stubGlobal("navigator", { clipboard: { writeText } });

    await writeClipboard("payload");

    expect(writeText).toHaveBeenCalledWith("payload");
    vi.unstubAllGlobals();
  });

  it("does not throw when both paths fail", async () => {
    tauriInvoke.mockRejectedValue(new Error("no such command"));
    vi.stubGlobal("navigator", {
      clipboard: { writeText: vi.fn().mockRejectedValue(new Error("denied")) },
    });

    await expect(writeClipboard("payload")).resolves.toBeUndefined();
    vi.unstubAllGlobals();
  });
});
