<script setup lang="ts">
import { computed } from "vue";
import type { FileEntry } from "@/types/sftp";
import { useI18n } from "vue-i18n";

const { t } = useI18n();

const props = defineProps<{
  visible: boolean;
  entry: FileEntry | null;
}>();

defineEmits<{
  close: [];
}>();

function formatSize(bytes: number): string {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return (
    Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i]
  );
}

function formatDate(timestamp: number | undefined | null): string {
  if (!timestamp) return "—";
  return new Date(timestamp * 1000).toLocaleString();
}

const displaySize = computed(() => {
  if (!props.entry) return "";
  return formatSize(props.entry.size);
});

const displayDate = computed(() => {
  if (!props.entry) return "";
  return formatDate(props.entry.mtime);
});

const displayType = computed(() => {
  if (!props.entry) return "";
  return props.entry.isDir ? t("sftp.directory") : t("sftp.file");
});
</script>

<template>
  <el-dialog
    :model-value="visible"
    :title="t('sftp.fileInfo')"
    width="450px"
    @close="$emit('close')"
  >
    <div v-if="entry" class="space-y-4">
      <div class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.name") }}:</span>
        <span style="color: var(--tm-text-primary)" class="font-mono font-medium">
          {{ entry.name }}
        </span>
      </div>

      <div class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.type") }}:</span>
        <span style="color: var(--tm-text-primary)">{{ displayType }}</span>
      </div>

      <div class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.size") }}:</span>
        <span style="color: var(--tm-text-primary)">{{ displaySize }}</span>
      </div>

      <div class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.permissions") }}:</span>
        <span
          style="color: var(--tm-text-primary)"
          class="font-mono font-medium"
        >
          {{ entry.permissions || "—" }}
        </span>
      </div>

      <div v-if="entry.uid !== undefined" class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.uid") }}:</span>
        <span style="color: var(--tm-text-primary)">{{ entry.uid }}</span>
      </div>

      <div v-if="entry.gid !== undefined" class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.gid") }}:</span>
        <span style="color: var(--tm-text-primary)">{{ entry.gid }}</span>
      </div>

      <div v-if="entry.mtime !== undefined" class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.modified") }}:</span>
        <span style="color: var(--tm-text-primary)">{{ displayDate }}</span>
      </div>

      <div class="flex justify-between items-center">
        <span style="color: var(--tm-text-secondary)">{{ t("sftp.symlink") }}:</span>
        <span style="color: var(--tm-text-primary)">
          {{ entry.isSymlink ? t("sftp.yes") : t("sftp.no") }}
        </span>
      </div>
    </div>

    <template #footer>
      <el-button @click="$emit('close')">{{ t("sftp.close") }}</el-button>
    </template>
  </el-dialog>
</template>
