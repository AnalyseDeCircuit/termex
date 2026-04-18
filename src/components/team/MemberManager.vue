<script setup lang="ts">
import { useI18n } from "vue-i18n";
import { ElMessageBox, ElMessage } from "element-plus";
import { useTeamStore } from "@/stores/teamStore";
import { useTeamPermission } from "@/composables/useTeamPermission";

const { t } = useI18n();
const teamStore = useTeamStore();
const { can } = useTeamPermission();

async function handleRoleChange(uname: string, role: string) {
  await teamStore.setMemberRole(uname, role);
}

async function handleRemoveMember(uname: string) {
  try {
    await ElMessageBox.confirm(
      t("team.memberRemoveConfirm", { name: uname }),
      t("team.memberRemove"),
      { type: "warning" },
    );
    await teamStore.removeMember(uname);
    ElMessage.success(t("team.memberRemoved", { name: uname }));
  } catch { /* cancelled */ }
}
</script>

<template>
  <div class="space-y-1">
    <label class="text-xs" style="color: var(--tm-text-secondary)">
      {{ t("team.members") }}
    </label>
    <div
      v-for="member in teamStore.members"
      :key="member.username"
      class="flex items-center gap-2 px-2 py-1 rounded text-xs"
      style="background: var(--tm-bg-hover)"
    >
      <span class="flex-1" style="color: var(--tm-text-primary)">
        {{ member.username }}
      </span>
      <el-select
        v-if="can('TeamRoleAssign') && member.role !== 'admin'"
        :model-value="member.role"
        size="small"
        style="width: 100px"
        @change="(val: string) => handleRoleChange(member.username, val)"
      >
        <el-option value="ops" :label="t('teamV2.roleOps')" />
        <el-option value="developer" :label="t('teamV2.roleDeveloper')" />
        <el-option value="viewer" :label="t('teamV2.roleViewer')" />
      </el-select>
      <span v-else class="text-[10px]" style="color: var(--tm-text-muted)">
        {{ member.role }}
      </span>
      <button
        v-if="can('TeamRemove') && member.role !== 'admin'"
        class="text-[10px] hover:text-red-400 transition-colors"
        style="color: var(--tm-text-muted)"
        @click="handleRemoveMember(member.username)"
      >
        &times;
      </button>
    </div>
  </div>
</template>
