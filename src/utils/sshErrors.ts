/**
 * Markers emitted by the Rust SSH layer.
 *
 * Errors are flattened to strings at the Tauri command boundary, so these must
 * stay byte-identical to the constants in
 * `crates/termex-core/src/ssh/mod.rs`.
 */
export const KEY_PASSPHRASE_REQUIRED = "ssh:key-passphrase-required";
export const KEY_PASSPHRASE_INCORRECT = "ssh:key-passphrase-incorrect";

/** Raised frontend-side when the user dismisses the passphrase prompt. */
export const KEY_PASSPHRASE_CANCELLED = "ssh:key-passphrase-cancelled";

/** Normalise the many shapes an IPC rejection can arrive in. */
function messageOf(err: unknown): string {
  if (typeof err === "string") return err;
  if (err instanceof Error) return err.message;
  if (err && typeof err === "object" && "message" in err) {
    return String((err as { message: unknown }).message);
  }
  return String(err ?? "");
}

/** The key is encrypted and no usable passphrase was available. */
export function needsKeyPassphrase(err: unknown): boolean {
  return messageOf(err).includes(KEY_PASSPHRASE_REQUIRED);
}

/** A passphrase was supplied and rejected — worth asking again. */
export function wrongKeyPassphrase(err: unknown): boolean {
  return messageOf(err).includes(KEY_PASSPHRASE_INCORRECT);
}

/** Either backend condition: the connection can be retried by prompting. */
export function isPassphraseChallenge(err: unknown): boolean {
  return needsKeyPassphrase(err) || wrongKeyPassphrase(err);
}

/** The user dismissed the prompt rather than supplying a passphrase. */
export function passphraseCancelled(err: unknown): boolean {
  return messageOf(err).includes(KEY_PASSPHRASE_CANCELLED);
}

/**
 * Any passphrase outcome that automatic retry cannot improve on — the user has
 * already been asked, so a backoff loop must stop instead of re-prompting.
 */
export function isPassphraseTerminal(err: unknown): boolean {
  return isPassphraseChallenge(err) || passphraseCancelled(err);
}
