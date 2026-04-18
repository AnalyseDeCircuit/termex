<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import { useTeamStore } from "@/stores/teamStore";
import type { GitAuthConfig } from "@/types/team";

const { t } = useI18n();
const teamStore = useTeamStore();

import { useTeamPermission } from "@/composables/useTeamPermission";
import AuditDashboard from "./AuditDashboard.vue";
import InviteDialog from "@/components/team/InviteDialog.vue";
import ConflictResolver from "@/components/team/ConflictResolver.vue";
import RoleEditor from "@/components/team/RoleEditor.vue";
import MemberManager from "@/components/team/MemberManager.vue";
import type { ConflictItem } from "@/types/team";
const { can } = useTeamPermission();

const showAudit = ref(false);
const inviteDialogVisible = ref(false);
const roleEditorVisible = ref(false);
const conflictDialogVisible = ref(false);
const pendingConflicts = ref<ConflictItem[]>([]);

// ── Form state ──
const formMode = ref<"idle" | "create" | "join">("idle");
const loading = ref(false);

const teamName = ref("");
const passphrase = ref("");
const passphraseConfirm = ref("");
const repoUrl = ref("");
const username = ref("");
const gitAuthType = ref<"ssh_key" | "https_token" | "https_userpass">("ssh_key");
const sshKeyPath = ref("~/.ssh/id_ed25519");
const token = ref("");
const gitUsername = ref("");
const gitPassword = ref("");

function resetForm() {
  teamName.value = "";
  passphrase.value = "";
  passphraseConfirm.value = "";
  repoUrl.value = "";
  username.value = "";
  gitAuthType.value = "ssh_key";
  sshKeyPath.value = "~/.ssh/id_ed25519";
  token.value = "";
  gitUsername.value = "";
  gitPassword.value = "";
}

function startCreate() {
  resetForm();
  formMode.value = "create";
}

function startJoin() {
  resetForm();
  formMode.value = "join";
}

function cancelForm() {
  formMode.value = "idle";
}

function buildGitAuth(): GitAuthConfig {
  return {
    authType: gitAuthType.value,
    sshKeyPath: gitAuthType.value === "ssh_key" ? sshKeyPath.value : undefined,
    token: gitAuthType.value === "https_token" ? token.value : undefined,
    username: gitAuthType.value === "https_userpass" ? gitUsername.value : undefined,
    password: gitAuthType.value === "https_userpass" ? gitPassword.value : undefined,
  };
}

function canSubmit(): boolean {
  if (!repoUrl.value.trim() || !username.value.trim() || passphrase.value.length < 8) return false;
  if (formMode.value === "create") {
    return teamName.value.trim().length > 0 && passphrase.value === passphraseConfirm.value;
  }
  return true;
}

async function handleSubmit() {
  if (!canSubmit()) return;
  loading.value = true;
  try {
    const auth = buildGitAuth();
    if (formMode.value === "create") {
      await teamStore.create(teamName.value.trim(), passphrase.value, repoUrl.value.trim(), username.value.trim(), auth);
      ElMessage.success(t("team.createSuccess"));
    } else {
      await teamStore.join(repoUrl.value.trim(), passphrase.value, username.value.trim(), auth);
      ElMessage.success(t("team.joinSuccess"));
    }
    formMode.value = "idle";
    teamStore.loadMembers();
  } catch (e) {
    ElMessage.error(String(e));
  } finally {
    loading.value = false;
  }
}

// ── Joined state actions ──
async function handleSync() {
  try {
    const result = await teamStore.sync();
    if (result.conflicts.length > 0) {
      pendingConflicts.value = result.conflicts;
      conflictDialogVisible.value = true;
      ElMessage.warning(t("teamV2.conflictPending", { count: result.conflicts.length }));
    } else {
      ElMessage.success(t("team.syncSuccess", { imported: result.imported, exported: result.exported }));
    }
  } catch (e) {
    const msg = String(e);
    // "team key not loaded" is handled centrally by teamStore (shows passphrase dialog)
    if (!msg.includes("team key not loaded")) {
      ElMessage.error(msg);
    }
  }
}

function onConflictsResolved() {
  pendingConflicts.value = [];
  teamStore.loadStatus();
}

async function handleLeave() {
  try {
    await ElMessageBox.confirm(t("team.leaveConfirm"), t("team.leave"), { type: "warning" });
    await teamStore.leave();
    ElMessage.success(t("team.leftSuccess"));
  } catch { /* cancelled */ }
}

async function handleRotateKey() {
  try {
    const { value: oldPass } = await ElMessageBox.prompt(t("team.currentPassphrase"), {
      inputType: "password",
    });
    const { value: newPass } = await ElMessageBox.prompt(t("team.newPassphrase"), {
      inputType: "password",
    });
    if (newPass.length < 8) {
      ElMessage.warning(t("team.passphraseTooShort"));
      return;
    }
    await teamStore.rotateKey(oldPass, newPass);
    ElMessage.success(t("team.rotateKeySuccess"));
  } catch { /* cancelled */ }
}

function formatLastSync(ts: string | null): string {
  if (!ts) return t("team.neverSynced");
  const d = new Date(ts);
  const diff = Date.now() - d.getTime();
  if (diff < 60_000) return t("team.justNow");
  if (diff < 3600_000) return `${Math.floor(diff / 60_000)} ${t("team.minutesAgo")}`;
  return d.toLocaleString();
}

onMounted(async () => {
  await teamStore.loadStatus();
  if (teamStore.isJoined) {
    teamStore.loadMembers();
    // Proactively prompt for passphrase if key was not restored from keychain
    if (teamStore.needsPassphrase) {
      teamStore.passphraseDialogVisible = true;
    }
  }
});
</script>

<template>
  <div class="space-y-5">
    <h3 class="text-sm font-medium" style="color: var(--tm-text-primary)">
      {{ t("team.title") }}
    </h3>

    <!-- ═══ Not joined: idle or form ═══ -->
    <template v-if="!teamStore.isJoined">
      <!-- Idle: show description + buttons -->
      <template v-if="formMode === 'idle'">
        <p class="text-xs" style="color: var(--tm-text-muted)">
          {{ t("team.description") }}
        </p>
        <div class="flex gap-3">
          <el-button size="small" type="primary" @click="startCreate">
            {{ t("team.create") }}
          </el-button>
          <el-button size="small" @click="startJoin">
            {{ t("team.join") }}
          </el-button>
        </div>
      </template>

      <!-- Inline form: create or join -->
      <template v-else>
        <div class="space-y-3">
          <!-- Mode tabs -->
          <div class="flex gap-1">
            <button
              class="text-xs px-3 py-1 rounded transition-colors"
              :style="{
                background: formMode === 'create' ? 'var(--el-color-primary-light-9)' : 'transparent',
                color: formMode === 'create' ? 'var(--el-color-primary)' : 'var(--tm-text-muted)',
                border: '1px solid ' + (formMode === 'create' ? 'var(--el-color-primary-light-5)' : 'var(--tm-border)'),
              }"
              @click="formMode = 'create'"
            >
              {{ t("team.create") }}
            </button>
            <button
              class="text-xs px-3 py-1 rounded transition-colors"
              :style="{
                background: formMode === 'join' ? 'var(--el-color-primary-light-9)' : 'transparent',
                color: formMode === 'join' ? 'var(--el-color-primary)' : 'var(--tm-text-muted)',
                border: '1px solid ' + (formMode === 'join' ? 'var(--el-color-primary-light-5)' : 'var(--tm-border)'),
              }"
              @click="formMode = 'join'"
            >
              {{ t("team.join") }}
            </button>
          </div>

          <!-- Team name (create only) -->
          <div v-if="formMode === 'create'" class="space-y-1">
            <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("team.teamName") }}</label>
            <el-input v-model="teamName" size="small" />
          </div>

          <!-- Repo URL -->
          <div class="space-y-1">
            <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("team.repoUrl") }}</label>
            <el-input v-model="repoUrl" size="small" :placeholder="t('team.repoUrlHint')" />
          </div>

          <!-- Username -->
          <div class="space-y-1">
            <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("team.username") }}</label>
            <el-input v-model="username" size="small" :placeholder="t('team.usernameHint')" />
          </div>

          <!-- Passphrase -->
          <div class="space-y-1">
            <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("team.passphrase") }}</label>
            <el-input v-model="passphrase" type="password" show-password size="small" />
            <p class="text-[10px]" style="color: var(--tm-text-muted)">{{ t("team.passphraseHint") }}</p>
            <p
              v-if="passphrase.length > 0 && passphrase.length < 8"
              class="text-[10px]"
              style="color: var(--el-color-danger)"
            >
              {{ t("team.passphraseTooShort") }}
            </p>
          </div>

          <!-- Confirm passphrase (create only) -->
          <div v-if="formMode === 'create'" class="space-y-1">
            <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("team.passphraseConfirm") }}</label>
            <el-input v-model="passphraseConfirm" type="password" show-password size="small" />
            <p
              v-if="passphraseConfirm.length > 0 && passphrase !== passphraseConfirm"
              class="text-[10px]"
              style="color: var(--el-color-danger)"
            >
              {{ t("team.passphraseMismatch") }}
            </p>
          </div>

          <!-- Git auth -->
          <div class="flex items-center gap-3">
            <label class="text-xs shrink-0" style="color: var(--tm-text-secondary)">{{ t("team.gitAuth") }}</label>
            <el-radio-group v-model="gitAuthType" size="small">
              <el-radio-button value="ssh_key">{{ t("team.gitAuthSsh") }}</el-radio-button>
              <el-radio-button value="https_token">{{ t("team.gitAuthToken") }}</el-radio-button>
              <el-radio-button value="https_userpass">{{ t("team.gitAuthUserPass") }}</el-radio-button>
            </el-radio-group>
          </div>

          <!-- Git auth fields -->
          <div v-if="gitAuthType === 'ssh_key'" class="space-y-1">
            <el-input v-model="sshKeyPath" size="small" placeholder="~/.ssh/id_ed25519" />
          </div>
          <div v-else-if="gitAuthType === 'https_token'" class="space-y-1">
            <el-input v-model="token" type="password" show-password size="small" placeholder="ghp_..." />
          </div>
          <div v-else class="space-y-2">
            <el-input v-model="gitUsername" size="small" :placeholder="t('team.username')" />
            <el-input v-model="gitPassword" type="password" show-password size="small" />
          </div>

          <!-- Actions -->
          <div class="flex gap-2 pt-1">
            <el-button
              size="small"
              type="primary"
              :disabled="!canSubmit()"
              :loading="loading"
              @click="handleSubmit"
            >
              {{ formMode === "create" ? t("team.create") : t("team.join") }}
            </el-button>
            <el-button size="small" @click="cancelForm">
              {{ t("snippet.cancel") }}
            </el-button>
          </div>
        </div>
      </template>
    </template>

    <!-- ═══ Joined ═══ -->
    <template v-else>
      <!-- Info card -->
      <div class="p-3 rounded space-y-2" style="border: 1px solid var(--tm-border)">
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium" style="color: var(--tm-text-primary)">
            {{ teamStore.teamName }}
          </span>
          <span
            class="text-[10px] px-1.5 py-0.5 rounded"
            style="background: var(--el-color-primary-light-9); color: var(--el-color-primary)"
          >
            {{ teamStore.status.role }}
          </span>
        </div>
        <div class="text-[10px] space-y-0.5" style="color: var(--tm-text-muted)">
          <div>{{ teamStore.status.repoUrl }}</div>
          <div>
            {{ t("team.lastSync") }}: {{ formatLastSync(teamStore.status.lastSync) }}
            &middot; {{ t("team.members") }}: {{ teamStore.status.memberCount }}
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex gap-2">
        <el-button size="small" :loading="teamStore.syncing" :icon="Refresh" @click="handleSync">
          {{ t("team.sync") }}
        </el-button>
        <el-button size="small" type="danger" plain @click="handleLeave">
          {{ t("team.leave") }}
        </el-button>
      </div>

      <!-- Pending conflicts hint -->
      <button
        v-if="pendingConflicts.length > 0"
        class="text-xs px-2 py-1 rounded transition-colors"
        style="background: var(--el-color-warning-light-9); color: var(--el-color-warning)"
        @click="conflictDialogVisible = true"
      >
        {{ t("teamV2.conflictPending", { count: pendingConflicts.length }) }}
      </button>

      <!-- Member list -->
      <MemberManager />

      <!-- Invite + Security actions -->
      <div class="flex flex-wrap gap-2">
        <el-button v-if="can('TeamInvite')" size="small" @click="inviteDialogVisible = true">
          {{ t("teamV2.inviteMember") }}
        </el-button>
        <el-button v-if="can('TeamSettingsEdit')" size="small" @click="roleEditorVisible = true">
          {{ t("teamV2.manageRoles") }}
        </el-button>
        <el-button v-if="can('TeamSettingsEdit')" size="small" @click="handleRotateKey">
          {{ t("team.rotateKey") }}
        </el-button>
      </div>

      <!-- Invite dialog -->
      <InviteDialog v-model="inviteDialogVisible" />

      <!-- Role editor -->
      <RoleEditor v-model="roleEditorVisible" />

      <!-- Conflict resolver -->
      <ConflictResolver
        v-model="conflictDialogVisible"
        :conflicts="pendingConflicts"
        @resolved="onConflictsResolved"
      />

      <!-- Audit section -->
      <div v-if="can('AuditView')" class="space-y-2">
        <button
          class="text-xs flex items-center gap-1 transition-colors"
          style="color: var(--tm-text-secondary)"
          @click="showAudit = !showAudit"
        >
          <svg class="w-3 h-3 transition-transform" :class="{ 'rotate-90': showAudit }" viewBox="0 0 24 24" fill="currentColor"><path d="M10 6L16 12L10 18Z" /></svg>
          {{ t("teamV2.auditDashboard") }}
        </button>
        <AuditDashboard v-if="showAudit" />
      </div>
    </template>
  </div>
</template>
