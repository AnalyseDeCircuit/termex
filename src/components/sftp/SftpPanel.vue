<script setup lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useSftpStore } from "@/stores/sftpStore";
import { Close } from "@element-plus/icons-vue";
import LocalFilePane from "./LocalFilePane.vue";
import RemoteFilePane from "./RemoteFilePane.vue";
import TransferBar from "./TransferBar.vue";

const { t } = useI18n();
const sftpStore = useSftpStore();

const hasActiveTransfers = computed(
  () => sftpStore.activeTransfers.length > 0,
);

function handleClose() {
  sftpStore.close();
}
</script>

<template>
  <div class="flex flex-col" style="background: var(--tm-bg-surface); border-top: 1px solid var(--tm-border)">
    <!-- Header -->
    <div class="flex items-center justify-between px-2 h-7 shrink-0" style="border-bottom: 1px solid var(--tm-border)">
      <span class="text-[10px] font-medium" style="color: var(--tm-text-secondary)">SFTP</span>
      <button class="tm-icon-btn p-0.5 rounded" :title="t('sftp.close')" @click="handleClose">
        <el-icon :size="12"><Close /></el-icon>
      </button>
    </div>

    <!-- Dual pane -->
    <div class="flex-1 flex min-h-0">
      <!-- Left: Local -->
      <LocalFilePane class="flex-1" />

      <!-- Divider -->
      <div class="w-px shrink-0" style="background: var(--tm-border)" />

      <!-- Right: Remote -->
      <RemoteFilePane class="flex-1" />
    </div>

    <!-- Transfer bar -->
    <TransferBar v-if="hasActiveTransfers" />
  </div>
</template>
