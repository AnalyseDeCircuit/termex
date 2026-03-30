<script setup lang="ts">
import { computed, ref } from "vue";
import { useI18n } from "vue-i18n";
import { useSftpStore } from "@/stores/sftpStore";
import { Close } from "@element-plus/icons-vue";
import LocalFilePane from "./LocalFilePane.vue";
import RemoteFilePane from "./RemoteFilePane.vue";
import TransfersPanel from "./TransfersPanel.vue";

const { t } = useI18n();
const sftpStore = useSftpStore();

const activeTab = ref<"files" | "transfers">("files");

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
      <div class="flex items-center gap-2">
        <span class="text-[10px] font-medium" style="color: var(--tm-text-secondary)">SFTP</span>
        <!-- Tab buttons -->
        <button
          :class="[
            'text-[10px] px-2 py-0.5 rounded transition-colors',
            activeTab === 'files'
              ? 'font-medium'
              : 'opacity-60 hover:opacity-100',
          ]"
          style="color: var(--tm-text-secondary)"
          @click="activeTab = 'files'"
        >
          {{ t("sftp.files") }}
        </button>
        <button
          :class="[
            'text-[10px] px-2 py-0.5 rounded transition-colors relative',
            activeTab === 'transfers'
              ? 'font-medium'
              : 'opacity-60 hover:opacity-100',
          ]"
          style="color: var(--tm-text-secondary)"
          @click="activeTab = 'transfers'"
        >
          {{ t("sftp.transfers") }}
          <span v-if="hasActiveTransfers" class="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full text-white text-[8px] flex items-center justify-center font-bold">
            {{ sftpStore.activeTransfers.length }}
          </span>
        </button>
      </div>
      <button class="tm-icon-btn p-0.5 rounded" :title="t('sftp.close')" @click="handleClose">
        <el-icon :size="12"><Close /></el-icon>
      </button>
    </div>

    <!-- Content -->
    <div class="flex-1 min-h-0 flex flex-col">
      <!-- Files tab -->
      <div v-if="activeTab === 'files'" class="h-full flex min-h-0">
        <!-- Left: Local -->
        <LocalFilePane class="flex-1" />

        <!-- Divider -->
        <div class="w-px shrink-0" style="background: var(--tm-border)" />

        <!-- Right: Remote -->
        <RemoteFilePane class="flex-1" />
      </div>

      <!-- Transfers tab -->
      <TransfersPanel v-else />
    </div>
  </div>
</template>
