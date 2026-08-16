import { ElMessageBox } from "element-plus";
import { i18n } from "@/i18n";
import { tauriInvoke } from "@/utils/tauri";
import {
  KEY_PASSPHRASE_CANCELLED,
  isPassphraseChallenge,
  wrongKeyPassphrase,
} from "@/utils/sshErrors";

/** Attempts before giving up, so a mistyped passphrase does not loop forever. */
const MAX_PASSPHRASE_ATTEMPTS = 3;

/**
 * Invoke `ssh_connect`, prompting for the key passphrase when the backend
 * reports the private key is encrypted.
 *
 * Previously a passphrase-protected key could only be used if its passphrase
 * was stored on the server record, which meant a key the user deliberately kept
 * out of any credential store was unusable (issue #21). The passphrase entered
 * here is sent for this attempt only and is never written to the database or
 * the keychain.
 *
 * @returns the real session id
 */
export async function connectWithPassphrasePrompt(
  serverId: string,
  serverName: string,
): Promise<string> {
  const t = i18n.global.t;

  try {
    return await tauriInvoke<string>("ssh_connect", { serverId });
  } catch (err) {
    if (!isPassphraseChallenge(err)) throw err;

    let lastError = err;
    for (let attempt = 0; attempt < MAX_PASSPHRASE_ATTEMPTS; attempt++) {
      // A rejected passphrase explains itself on the next prompt.
      const hint = wrongKeyPassphrase(lastError)
        ? t("connection.keyPassphraseWrong")
        : t("connection.keyPassphraseHint", { name: serverName });

      // ElMessageBox rejects with an opaque "cancel"/"close" reason. Re-throw it
      // as a tagged error so callers can tell "user declined" apart from a
      // genuine connection failure and stop retrying.
      let value: string;
      try {
        ({ value } = await ElMessageBox.prompt(
          hint,
          t("connection.keyPassphraseTitle"),
          {
            confirmButtonText: t("connection.save"),
            cancelButtonText: t("connection.cancel"),
            inputType: "password",
            inputPattern: /.+/,
            inputErrorMessage: t("connection.keyPassphraseEmpty"),
          },
        ));
      } catch {
        throw new Error(KEY_PASSPHRASE_CANCELLED);
      }

      try {
        return await tauriInvoke<string>("ssh_connect", {
          serverId,
          passphrase: value,
        });
      } catch (retryErr) {
        if (!isPassphraseChallenge(retryErr)) throw retryErr;
        lastError = retryErr;
      }
    }

    throw lastError;
  }
}
