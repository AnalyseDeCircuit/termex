import { describe, it, expect } from "vitest";
import {
  KEY_PASSPHRASE_CANCELLED,
  KEY_PASSPHRASE_INCORRECT,
  KEY_PASSPHRASE_REQUIRED,
  isPassphraseChallenge,
  isPassphraseTerminal,
  needsKeyPassphrase,
  passphraseCancelled,
  wrongKeyPassphrase,
} from "@/utils/sshErrors";

describe("ssh passphrase error detection", () => {
  // Tauri rejects with a bare string; other layers wrap in Error or an object.
  it.each([
    ["string", KEY_PASSPHRASE_REQUIRED],
    ["Error", new Error(KEY_PASSPHRASE_REQUIRED)],
    ["object with message", { message: KEY_PASSPHRASE_REQUIRED }],
  ])("recognises a required-passphrase failure delivered as %s", (_label, err) => {
    expect(needsKeyPassphrase(err)).toBe(true);
    expect(isPassphraseChallenge(err)).toBe(true);
  });

  it("recognises the marker inside a longer message", () => {
    expect(
      needsKeyPassphrase(`connect failed: ${KEY_PASSPHRASE_REQUIRED}`),
    ).toBe(true);
  });

  it("separates an incorrect passphrase from a missing one", () => {
    expect(wrongKeyPassphrase(KEY_PASSPHRASE_INCORRECT)).toBe(true);
    expect(needsKeyPassphrase(KEY_PASSPHRASE_INCORRECT)).toBe(false);
    expect(isPassphraseChallenge(KEY_PASSPHRASE_INCORRECT)).toBe(true);
  });

  it("does not mistake an unrelated failure for a passphrase problem", () => {
    for (const err of [
      "authentication failed: password rejected",
      "connection failed: timed out",
      new Error("key error: The key is corrupt"),
      null,
      undefined,
    ]) {
      expect(isPassphraseChallenge(err)).toBe(false);
      expect(isPassphraseTerminal(err)).toBe(false);
    }
  });

  // A dismissed prompt must stop the reconnect backoff, but is not a backend
  // challenge — retrying the connection would just re-open the dialog.
  it("treats a cancelled prompt as terminal but not as a challenge", () => {
    const err = new Error(KEY_PASSPHRASE_CANCELLED);
    expect(passphraseCancelled(err)).toBe(true);
    expect(isPassphraseChallenge(err)).toBe(false);
    expect(isPassphraseTerminal(err)).toBe(true);
  });

  it("treats both backend conditions as terminal for reconnect", () => {
    expect(isPassphraseTerminal(KEY_PASSPHRASE_REQUIRED)).toBe(true);
    expect(isPassphraseTerminal(KEY_PASSPHRASE_INCORRECT)).toBe(true);
  });
});
