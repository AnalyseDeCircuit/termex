<script setup lang="ts">
import { inject, computed } from "vue";
import { useI18n } from "vue-i18n";
import { useSftpStore } from "@/stores/sftpStore";
import { tabSftpKey, type TabSftpContext } from "@/composables/useTabSftp";
import { Upload, Download, Sort, Close } from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import type { TransferItem } from "@/types/sftp";

const { t } = useI18n();
const sftpStore = useSftpStore();
const tabCtx = inject<TabSftpContext | null>(tabSftpKey, null);

// Normalize transfers access — TabSftpContext uses Ref, sftpStore uses reactive array
const transfers = computed(() =>
  tabCtx ? tabCtx.transfers.value : sftpStore.transfers,
);

function formatBytes(bytes: number): string {
  if (bytes === 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}

function getStatusText(item: TransferItem): string {
  if (item.error) return t("sftp.error");
  if (item.done) return t("sftp.completed");
  if (item.total === 0) return t("sftp.preparing");
  return `${Math.round((item.transferred / item.total) * 100)}%`;
}

function getStatusColor(item: TransferItem): string {
  if (item.error) return "#ef4444";
  if (item.done) return "#10b981";
  return "var(--tm-text-secondary)";
}

function getSubtitle(item: TransferItem): string {
  if (item.direction === "server-to-server") {
    return `${item.srcServerName ?? ""} → ${item.dstServerName ?? ""}`;
  }
  return item.localPath;
}

function handleClear() {
  if (tabCtx) {
    tabCtx.transfers.value = tabCtx.transfers.value.filter((t: TransferItem) => !t.done);
  } else {
    sftpStore.transfers = sftpStore.transfers.filter((t: TransferItem) => !t.done);
  }
  ElMessage.success(t("sftp.cleared"));
}

function handleRemoveTransfer(id: string) {
  const arr = tabCtx ? tabCtx.transfers.value : sftpStore.transfers;
  const idx = arr.findIndex((t: TransferItem) => t.id === id);
  if (idx !== -1) {
    arr.splice(idx, 1);
  }
}
</script>

<template>
  <div class="flex flex-col h-full min-w-0 overflow-auto">
    <!-- Header -->
    <div v-if="transfers.length > 0" class="flex items-center justify-between px-3 py-2 shrink-0 border-b" style="border-color: var(--tm-border)">
      <span class="text-xs font-medium" style="color: var(--tm-text-secondary)">
        {{ transfers.length }} {{ t("sftp.transfers") }}
      </span>
      <button
        class="text-xs px-2 py-1 rounded hover:bg-white/10 transition-colors"
        style="color: var(--tm-text-secondary)"
        @click="handleClear"
      >
        {{ t("sftp.clearCompleted") }}
      </button>
    </div>

    <!-- Transfers list -->
    <div v-if="transfers.length > 0" class="flex-1 overflow-auto">
      <div
        v-for="item in transfers"
        :key="item.id"
        :class="[
          'px-3 py-3 border-b transition-opacity',
          item.done && !item.error ? 'opacity-60' : '',
        ]"
        style="border-color: var(--tm-border)"
      >
        <div class="flex items-center gap-2 mb-2">
          <!-- Direction icon -->
          <el-icon :size="14">
            <Upload v-if="item.direction === 'upload'" />
            <Download v-else-if="item.direction === 'download'" />
            <Sort v-else />
          </el-icon>

          <div class="flex-1 min-w-0">
            <div class="text-xs font-medium truncate" style="color: var(--tm-text-primary)">
              {{ item.remotePath.split("/").pop() }}
            </div>
            <div class="text-[10px] truncate mt-0.5" style="color: var(--tm-text-muted)">
              {{ getSubtitle(item) }}
            </div>
            <!-- Error message -->
            <div v-if="item.error" class="text-[10px] truncate mt-0.5" style="color: #ef4444">
              {{ item.error }}
            </div>
          </div>

          <div class="text-right flex items-center gap-2">
            <div>
              <div class="text-xs font-medium" :style="{ color: getStatusColor(item) }">
                {{ getStatusText(item) }}
              </div>
              <div class="text-[10px]" style="color: var(--tm-text-muted)">
                {{ formatBytes(item.transferred) }}
                <span v-if="item.total > 0"> / {{ formatBytes(item.total) }}</span>
              </div>
            </div>
            <button
              class="text-xs p-1 rounded hover:bg-white/10 transition-colors flex-shrink-0"
              :title="t('sftp.remove')"
              @click="handleRemoveTransfer(item.id)"
            >
              <el-icon :size="12" style="color: var(--tm-text-muted)">
                <Close />
              </el-icon>
            </button>
          </div>
        </div>

        <!-- Progress bar -->
        <el-progress
          :percentage="item.total > 0 ? Math.round((item.transferred / item.total) * 100) : 0"
          :status="item.error ? 'exception' : item.done ? 'success' : undefined"
          :stroke-width="3"
          :show-text="false"
        />
      </div>
    </div>

    <!-- Empty state -->
    <div v-else class="flex-1 flex items-center justify-center" style="color: var(--tm-text-muted)">
      <span class="text-sm">{{ t("sftp.noTransfers") }}</span>
    </div>
  </div>
</template>
