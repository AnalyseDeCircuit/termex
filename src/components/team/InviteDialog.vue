<script setup lang="ts">
import { ref } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";

defineProps<{ modelValue: boolean }>();
const emit = defineEmits<{
  (e: "update:modelValue", v: boolean): void;
}>();

const { t } = useI18n();

const role = ref("developer");
const expiresDays = ref(7);
const generatedToken = ref("");
const copied = ref(false);

async function generate() {
  try {
    generatedToken.value = await tauriInvoke<string>("team_generate_invite_token", {
      role: role.value,
      expiresDays: expiresDays.value,
    });
    copied.value = false;
  } catch (err) {
    ElMessage.error(String(err));
  }
}

async function copyToken() {
  try {
    await navigator.clipboard.writeText(generatedToken.value);
    copied.value = true;
    setTimeout(() => { copied.value = false; }, 2000);
  } catch {
    ElMessage.error("Failed to copy");
  }
}

function close() {
  generatedToken.value = "";
  emit("update:modelValue", false);
}
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    :title="t('teamV2.inviteMember')"
    width="400px"
    @update:model-value="close"
  >
    <div class="flex flex-col gap-4">
      <!-- Role selection -->
      <div class="flex flex-col gap-1">
        <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("teamV2.inviteRole") }}</label>
        <el-select v-model="role" size="small">
          <el-option value="ops" :label="t('teamV2.roleOps')" />
          <el-option value="developer" :label="t('teamV2.roleDeveloper')" />
          <el-option value="viewer" :label="t('teamV2.roleViewer')" />
        </el-select>
      </div>

      <!-- Expiry -->
      <div class="flex flex-col gap-1">
        <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("teamV2.inviteExpiry") }}</label>
        <el-select v-model="expiresDays" size="small">
          <el-option :value="1" :label="t('teamV2.inviteDays', { n: 1 })" />
          <el-option :value="3" :label="t('teamV2.inviteDays', { n: 3 })" />
          <el-option :value="7" :label="t('teamV2.inviteDays', { n: 7 })" />
          <el-option :value="14" :label="t('teamV2.inviteDays', { n: 14 })" />
          <el-option :value="30" :label="t('teamV2.inviteDays', { n: 30 })" />
        </el-select>
      </div>

      <!-- Generate button -->
      <el-button type="primary" size="small" @click="generate">
        {{ t("teamV2.inviteGenerate") }}
      </el-button>

      <!-- Generated token -->
      <template v-if="generatedToken">
        <div class="flex flex-col gap-1">
          <label class="text-xs" style="color: var(--tm-text-secondary)">{{ t("teamV2.inviteCode") }}</label>
          <div
            class="flex items-center gap-1 rounded px-2 py-1.5"
            style="background: var(--tm-bg-secondary)"
          >
            <code class="text-[10px] flex-1 break-all select-all" style="color: var(--tm-text-primary)">
              {{ generatedToken }}
            </code>
            <button
              class="shrink-0 p-1 rounded hover:bg-[var(--tm-bg-hover)] transition-colors"
              @click="copyToken"
            >
              <svg v-if="!copied" class="w-3.5 h-3.5" style="color: var(--tm-text-muted)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="9" y="9" width="13" height="13" rx="2" /><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
              </svg>
              <svg v-else class="w-3.5 h-3.5 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </button>
          </div>
        </div>

        <div class="text-[10px]" style="color: var(--tm-text-muted)">
          {{ t("teamV2.inviteHint") }}
        </div>
      </template>
    </div>
  </el-dialog>
</template>
