import { defineStore } from "pinia";
import { ref, computed } from "vue";
import { tauriInvoke } from "@/utils/tauri";
import type {
  Capability,
  TeamStatus,
  TeamMember,
  TeamSyncResult,
  GitAuthConfig,
  TeamInfo,
} from "@/types/team";

export const useTeamStore = defineStore("team", () => {
  const status = ref<TeamStatus>({
    joined: false,
    name: null,
    role: null,
    memberCount: 0,
    lastSync: null,
    hasPendingChanges: false,
    repoUrl: null,
    needsPassphrase: false,
  });

  const members = ref<TeamMember[]>([]);
  const syncing = ref(false);
  const myCapabilities = ref<Capability[]>([]);
  /** Set to true when an operation fails because the team key is not loaded. */
  const passphraseDialogVisible = ref(false);
  /** Brief message shown in status bar after sync completes/fails. Auto-clears after a few seconds. */
  const syncStatusMessage = ref("");

  const isJoined = computed(() => status.value.joined);
  const isAdmin = computed(() => status.value.role === "admin");
  const teamName = computed(() => status.value.name || "");
  const canPush = computed(() => myCapabilities.value.includes("SyncPush"));
  const needsPassphrase = computed(() => status.value.needsPassphrase);

  async function loadStatus() {
    try {
      status.value = await tauriInvoke<TeamStatus>("team_get_status");
      if (status.value.joined) {
        await loadCapabilities();
      } else {
        myCapabilities.value = [];
      }
    } catch {
      // Not in a team — keep default status
    }
  }

  async function loadCapabilities() {
    try {
      myCapabilities.value = await tauriInvoke<Capability[]>("team_my_capabilities");
    } catch {
      myCapabilities.value = [];
    }
  }

  async function create(
    name: string,
    passphrase: string,
    repoUrl: string,
    username: string,
    gitAuth: GitAuthConfig,
  ): Promise<TeamInfo> {
    const info = await tauriInvoke<TeamInfo>("team_create", {
      name,
      passphrase,
      repoUrl,
      username,
      gitAuth,
    });
    await loadStatus();
    return info;
  }

  async function join(
    repoUrl: string,
    passphrase: string,
    username: string,
    gitAuth: GitAuthConfig,
  ): Promise<TeamInfo> {
    const info = await tauriInvoke<TeamInfo>("team_join", {
      repoUrl,
      passphrase,
      username,
      gitAuth,
    });
    await loadStatus();
    return info;
  }

  let syncStatusTimer: ReturnType<typeof setTimeout> | null = null;

  function setSyncStatus(msg: string, durationMs = 5000) {
    syncStatusMessage.value = msg;
    if (syncStatusTimer) clearTimeout(syncStatusTimer);
    syncStatusTimer = setTimeout(() => { syncStatusMessage.value = ""; }, durationMs);
  }

  async function sync(): Promise<TeamSyncResult> {
    syncing.value = true;
    syncStatusMessage.value = "";
    try {
      const result = await tauriInvoke<TeamSyncResult>("team_sync");
      await loadStatus();
      const total = result.imported + result.exported;
      if (total > 0) {
        setSyncStatus(`\u2713 ${result.imported}\u2193 ${result.exported}\u2191`);
      } else {
        setSyncStatus("\u2713");
      }
      return result;
    } catch (e) {
      const msg = String(e);
      if (msg.includes("team key not loaded")) {
        passphraseDialogVisible.value = true;
      } else {
        setSyncStatus("\u2717 failed");
      }
      throw e;
    } finally {
      syncing.value = false;
    }
  }

  /** Called after passphrase verified — clears flag and retries sync. */
  async function onPassphraseVerified(): Promise<TeamSyncResult | null> {
    passphraseDialogVisible.value = false;
    status.value.needsPassphrase = false;
    try {
      return await sync();
    } catch {
      return null;
    }
  }

  async function leave() {
    await tauriInvoke("team_leave");
    status.value = {
      joined: false,
      name: null,
      role: null,
      memberCount: 0,
      lastSync: null,
      hasPendingChanges: false,
      repoUrl: null,
      needsPassphrase: false,
    };
    members.value = [];
  }

  async function loadMembers() {
    members.value = await tauriInvoke<TeamMember[]>("team_list_members");
  }

  async function setMemberRole(username: string, role: string) {
    await tauriInvoke("team_set_role", { targetUsername: username, role });
    await loadMembers();
  }

  async function removeMember(username: string) {
    await tauriInvoke("team_remove_member", { targetUsername: username });
    await loadMembers();
  }

  async function verifyPassphrase(
    passphrase: string,
    remember: boolean,
  ): Promise<boolean> {
    return await tauriInvoke<boolean>("team_verify_passphrase", {
      passphrase,
      remember,
    });
  }

  async function toggleShare(serverId: string, shared: boolean) {
    await tauriInvoke("team_toggle_share", { serverId, shared });
  }

  async function rotateKey(oldPassphrase: string, newPassphrase: string) {
    await tauriInvoke("team_rotate_key", { oldPassphrase, newPassphrase });
  }

  return {
    status,
    members,
    syncing,
    myCapabilities,
    isJoined,
    isAdmin,
    teamName,
    canPush,
    needsPassphrase,
    passphraseDialogVisible,
    syncStatusMessage,
    loadStatus,
    loadCapabilities,
    create,
    join,
    sync,
    leave,
    loadMembers,
    setMemberRole,
    removeMember,
    verifyPassphrase,
    toggleShare,
    rotateKey,
    onPassphraseVerified,
  };
});
