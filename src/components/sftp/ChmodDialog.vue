<script setup lang="ts">
import { ref, watch } from "vue";
import type { FileEntry } from "@/types/sftp";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";

const { t } = useI18n();

const props = defineProps<{
  visible: boolean;
  entry: FileEntry | null;
}>();

const emit = defineEmits<{
  confirm: [mode: number];
  close: [];
}>();

const modeInput = ref("");

watch(
  () => props.visible,
  (newVal) => {
    if (newVal && props.entry?.permissions) {
      // Parse existing permissions (e.g., "rwxr-xr-x" -> "755")
      // For simplicity, show the numeric input
      modeInput.value = "";
    } else {
      modeInput.value = "";
    }
  }
);

function handleConfirm() {
  const trimmed = modeInput.value.trim();
  if (!trimmed) {
    ElMessage.warning(t("sftp.chmodRequired"));
    return;
  }

  // Try to parse as octal
  const mode = parseInt(trimmed, 8);
  if (isNaN(mode) || mode < 0 || mode > 0o7777) {
    ElMessage.error(t("sftp.chmodInvalid"));
    return;
  }

  emit("confirm", mode);
}
</script>

<template>
  <el-dialog
    :model-value="visible"
    :title="t('sftp.chmod')"
    width="400px"
    @close="$emit('close')"
  >
    <div class="space-y-4">
      <div v-if="entry" style="color: var(--tm-text-secondary)">
        {{ t("sftp.chmodFile") }}: <strong style="color: var(--tm-text-primary)">{{ entry.name }}</strong>
      </div>

      <div>
        <label style="color: var(--tm-text-secondary); display: block; margin-bottom: 0.5rem">
          {{ t("sftp.chmodOctal") }}
        </label>
        <el-input
          v-model="modeInput"
          :placeholder="t('sftp.chmodExample')"
          type="text"
        />
        <div style="color: var(--tm-text-muted); font-size: 0.85rem; margin-top: 0.5rem">
          {{ t("sftp.chmodHelp") }}
        </div>
      </div>
    </div>

    <template #footer>
      <el-button @click="$emit('close')">{{ t("sftp.cancel") }}</el-button>
      <el-button type="primary" @click="handleConfirm">{{ t("sftp.confirm") }}</el-button>
    </template>
  </el-dialog>
</template>
