<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage, ElMessageBox } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";
import type { Capability, TeamRole } from "@/types/team";

defineProps<{ modelValue: boolean }>();
const emit = defineEmits<{
  (e: "update:modelValue", v: boolean): void;
}>();

const { t } = useI18n();
const roles = ref<Record<string, TeamRole>>({});
const presets = ["admin", "ops", "developer", "viewer"];

const allCapabilities: Capability[] = [
  "ServerConnect", "ServerCreate", "ServerEdit", "ServerDelete", "ServerViewCredentials",
  "SnippetCreate", "SnippetEdit", "SnippetDelete", "SnippetExecute",
  "TeamInvite", "TeamRemove", "TeamRoleAssign", "TeamSettingsEdit",
  "SyncPush", "SyncPull", "AuditView", "AuditExport",
];

async function loadRoles() {
  roles.value = await tauriInvoke<Record<string, TeamRole>>("team_list_roles");
}

const newRoleName = ref("");
const newRoleDisplay = ref("");

async function createRole() {
  if (!newRoleName.value.trim() || !newRoleDisplay.value.trim()) return;
  try {
    await tauriInvoke("team_role_create", {
      name: newRoleName.value.trim(),
      displayName: newRoleDisplay.value.trim(),
      capabilities: [],
    });
    newRoleName.value = "";
    newRoleDisplay.value = "";
    await loadRoles();
  } catch (err) {
    ElMessage.error(String(err));
  }
}

async function toggleCapability(roleName: string, cap: Capability) {
  const role = roles.value[roleName];
  if (!role) return;
  const caps = role.capabilities.includes(cap)
    ? role.capabilities.filter((c) => c !== cap)
    : [...role.capabilities, cap];
  try {
    await tauriInvoke("team_role_update", {
      name: roleName,
      displayName: role.displayName,
      capabilities: caps,
    });
    await loadRoles();
  } catch (err) {
    ElMessage.error(String(err));
  }
}

async function deleteRole(name: string) {
  try {
    await ElMessageBox.confirm(t("teamV2.deleteRoleConfirm"));
    await tauriInvoke("team_role_delete", { name });
    await loadRoles();
  } catch { /* cancelled */ }
}

function capLabel(cap: Capability): string {
  const key = `teamV2.cap${cap}`;
  const val = t(key);
  return val !== key ? val : cap.replace(/([A-Z])/g, " $1").trim();
}

function close() {
  emit("update:modelValue", false);
}

onMounted(loadRoles);
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    :title="t('teamV2.manageRoles')"
    width="560px"
    @update:model-value="close"
  >
    <div class="flex flex-col gap-4 max-h-[400px] overflow-y-auto">
      <div
        v-for="(role, name) in roles"
        :key="name"
        class="rounded p-3 space-y-2"
        style="border: 1px solid var(--tm-border)"
      >
        <div class="flex items-center gap-2">
          <span class="text-xs font-medium" style="color: var(--tm-text-primary)">
            {{ role.displayName }}
          </span>
          <span class="text-[10px] font-mono" style="color: var(--tm-text-muted)">{{ name }}</span>
          <span v-if="presets.includes(String(name))" class="ml-auto text-[10px]" style="color: var(--tm-text-muted)">
            {{ t("teamV2.presetRoleReadonly") }}
          </span>
          <button
            v-else
            class="ml-auto text-[10px] hover:text-red-400 transition-colors"
            style="color: var(--tm-text-muted)"
            @click="deleteRole(String(name))"
          >
            {{ t("teamV2.deleteRole") }}
          </button>
        </div>

        <div class="flex flex-wrap gap-1">
          <button
            v-for="cap in allCapabilities"
            :key="cap"
            class="text-[10px] px-1.5 py-0.5 rounded transition-colors"
            :style="{
              background: role.capabilities.includes(cap) ? 'var(--el-color-primary)' : 'var(--tm-bg-secondary)',
              color: role.capabilities.includes(cap) ? 'white' : 'var(--tm-text-muted)',
              opacity: presets.includes(String(name)) ? '0.6' : '1',
              cursor: presets.includes(String(name)) ? 'not-allowed' : 'pointer',
            }"
            :disabled="presets.includes(String(name))"
            @click="!presets.includes(String(name)) && toggleCapability(String(name), cap)"
          >
            {{ capLabel(cap) }}
          </button>
        </div>
      </div>

      <!-- Create new role -->
      <div class="rounded p-3 space-y-2" style="border: 1px dashed var(--tm-border)">
        <span class="text-xs font-medium" style="color: var(--tm-text-secondary)">{{ t("teamV2.createRole") }}</span>
        <div class="flex gap-2">
          <el-input v-model="newRoleName" size="small" placeholder="role-name" class="flex-1" />
          <el-input v-model="newRoleDisplay" size="small" :placeholder="t('teamV2.roleCustom')" class="flex-1" />
          <el-button size="small" type="primary" :disabled="!newRoleName.trim()" @click="createRole">+</el-button>
        </div>
      </div>
    </div>
  </el-dialog>
</template>
