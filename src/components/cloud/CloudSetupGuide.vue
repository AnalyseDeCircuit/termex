<script setup lang="ts">
import { ref } from "vue";
import { useCloudStore } from "@/stores/cloudStore";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";

const { t } = useI18n();
const cloudStore = useCloudStore();
const copiedTool = ref<string | null>(null);

const isMac = navigator.platform.startsWith("Mac");
const isLinux = navigator.platform.startsWith("Linux");

function getInstallCommand(toolName: string): string {
  switch (toolName) {
    case "kubectl":
      return isMac
        ? "brew install kubectl"
        : isLinux
          ? "sudo snap install kubectl --classic"
          : "choco install kubernetes-cli";
    case "aws":
      return isMac
        ? "brew install awscli"
        : isLinux
          ? "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o awscliv2.zip && unzip awscliv2.zip && sudo ./aws/install"
          : "msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi";
    case "session-manager-plugin":
      return isMac
        ? "brew install --cask session-manager-plugin"
        : isLinux
          ? "curl \"https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb\" -o ssm-plugin.deb && sudo dpkg -i ssm-plugin.deb"
          : "choco install ssm-session-manager-plugin";
    default:
      return "";
  }
}

function refresh() {
  cloudStore.detectTools();
}

async function copyCommand(toolName: string, command: string) {
  try {
    await navigator.clipboard.writeText(command);
    copiedTool.value = toolName;
    setTimeout(() => { copiedTool.value = null; }, 2000);
  } catch {
    ElMessage.error("Failed to copy");
  }
}
</script>

<template>
  <div class="p-4 flex flex-col gap-3">
    <div class="text-sm font-medium" style="color: var(--tm-text-primary)">
      {{ t("cloud.setupTitle") }}
    </div>
    <div class="text-xs" style="color: var(--tm-text-secondary)">
      {{ t("cloud.setupDesc") }}
    </div>

    <div class="flex flex-col gap-3 mt-2">
      <div
        v-for="tool in cloudStore.tools"
        :key="tool.name"
        class="rounded overflow-hidden"
        style="background: var(--tm-bg-secondary)"
      >
        <!-- Tool status row -->
        <div class="flex items-center gap-2 text-xs px-2.5 py-2">
          <span
            class="w-1.5 h-1.5 rounded-full shrink-0"
            :class="tool.available ? 'bg-green-500' : 'bg-red-500'"
          />
          <span class="font-mono font-medium" style="color: var(--tm-text-primary)">{{ tool.name }}</span>
          <span v-if="tool.available" class="text-green-500 ml-auto text-[11px]">
            {{ tool.version ? tool.version.substring(0, 30) : t("cloud.setupDetected") }}
          </span>
          <span v-else class="ml-auto text-[11px]" style="color: var(--tm-text-muted)">
            {{ t("cloud.setupNotInstalled") }}
          </span>
        </div>

        <!-- Install command (only for unavailable tools) -->
        <div v-if="!tool.available && getInstallCommand(tool.name)" class="px-2.5 pb-2">
          <div
            class="flex items-center gap-1 rounded px-2 py-1"
            style="background: var(--tm-bg-primary)"
          >
            <code class="text-[10px] flex-1 break-all" style="color: var(--tm-text-secondary)">
              {{ getInstallCommand(tool.name) }}
            </code>
            <button
              class="shrink-0 p-0.5 rounded hover:bg-[var(--tm-bg-hover)] transition-colors"
              :title="t('cloud.installCopy')"
              @click="copyCommand(tool.name, getInstallCommand(tool.name))"
            >
              <svg v-if="copiedTool !== tool.name" class="w-3 h-3" style="color: var(--tm-text-muted)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="9" y="9" width="13" height="13" rx="2" />
                <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1" />
              </svg>
              <svg v-else class="w-3 h-3 text-green-500" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="flex gap-2 mt-1">
      <button
        class="px-3 py-1.5 text-xs rounded transition-colors"
        style="background: var(--el-color-primary); color: white"
        @click="refresh"
      >
        {{ t("cloud.setupRefresh") }}
      </button>
    </div>
  </div>
</template>
