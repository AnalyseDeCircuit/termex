<script setup lang="ts">
import { ref, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { tauriInvoke } from "@/utils/tauri";

const { t } = useI18n();

interface SecurityStatus {
  keychainAvailable: boolean;
  keychainCredentialCount: number;
  protectionMode: string;
}

const status = ref<SecurityStatus | null>(null);
const loading = ref(true);

onMounted(async () => {
  try {
    status.value = await tauriInvoke<SecurityStatus>("security_status");
  } catch {
    status.value = null;
  } finally {
    loading.value = false;
  }
});

const isMac = navigator.platform.toUpperCase().includes("MAC");
const isWin = navigator.platform.toUpperCase().includes("WIN");
const platformName = isMac ? "macOS Keychain" : isWin ? "Windows Credential Manager" : "Secret Service (GNOME/KDE)";
</script>

<template>
  <div class="space-y-4">
    <h3 class="text-sm font-medium" style="color: var(--tm-text-primary)">
      {{ t("settings.security") }}
    </h3>

    <div v-if="loading" class="text-xs py-4 text-center" style="color: var(--tm-text-muted)">
      Loading...
    </div>

    <template v-else-if="status">
      <!-- Protection mode -->
      <div class="rounded p-3" style="border: 1px solid var(--tm-border)">
        <div class="flex items-center gap-2 mb-2">
          <span
            class="w-2 h-2 rounded-full shrink-0"
            :class="status.keychainAvailable ? 'bg-green-500' : 'bg-yellow-500'"
          />
          <span class="text-xs font-medium" style="color: var(--tm-text-primary)">
            {{ t("security.protectionMode") }}
          </span>
        </div>
        <div class="text-xs" style="color: var(--tm-text-secondary)">
          <template v-if="status.keychainAvailable">
            {{ t("security.keychainActive", { platform: platformName }) }}
          </template>
          <template v-else>
            {{ t("security.keychainUnavailable") }}
          </template>
        </div>
      </div>

      <!-- Credential stats -->
      <div class="rounded p-3" style="border: 1px solid var(--tm-border)">
        <div class="text-xs font-medium mb-1" style="color: var(--tm-text-primary)">
          {{ t("security.storedCredentials") }}
        </div>
        <div class="text-2xl font-bold" style="color: var(--tm-text-primary)">
          {{ status.keychainCredentialCount }}
        </div>
        <div class="text-[10px] mt-0.5" style="color: var(--tm-text-muted)">
          {{ t("security.credentialHint") }}
        </div>
      </div>

      <!-- How it works -->
      <div class="text-xs space-y-1.5" style="color: var(--tm-text-muted)">
        <div class="font-medium" style="color: var(--tm-text-secondary)">
          {{ t("security.howItWorks") }}
        </div>
        <ul class="list-disc pl-4 space-y-0.5">
          <li>{{ t("security.hint1") }}</li>
          <li>{{ t("security.hint2") }}</li>
          <li>{{ t("security.hint3") }}</li>
        </ul>
      </div>
    </template>
  </div>
</template>
