<script setup lang="ts">
import { ref, computed, watch, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessageBox } from "element-plus";
import { Plus, Delete } from "@element-plus/icons-vue";
import { useAiStore } from "@/stores/aiStore";
import { tauriInvoke } from "@/utils/tauri";
import type { ProviderInput, ProviderType } from "@/types/ai";
import {
  DEFAULT_MODELS,
  DEFAULT_MAX_TOKENS,
  PROVIDER_BASE_URLS,
  PROVIDER_NAMES,
} from "@/types/ai";

const { t } = useI18n();
const aiStore = useAiStore();

const showForm = ref(false);
const editingId = ref<string | null>(null);
const testing = ref(false);
const testResult = ref<{ ok: boolean; msg: string } | null>(null);

const ALL_PROVIDERS = Object.entries(PROVIDER_NAMES).map(([value, label]) => ({
  value: value as ProviderType,
  label,
}));

const form = ref<ProviderInput>({
  name: "",
  providerType: "openai",
  apiKey: null,
  apiBaseUrl: null,
  model: "gpt-4o",
  maxTokens: 4096,
  temperature: 0.7,
  isDefault: false,
});

const currentModels = computed(() => {
  return DEFAULT_MODELS[form.value.providerType as ProviderType] ?? [];
});

const currentBaseUrl = computed(() => {
  return PROVIDER_BASE_URLS[form.value.providerType as ProviderType] ?? "";
});

// Auto-fill base URL and first model when provider changes (only for new providers)
const skipWatch = ref(false);
watch(
  () => form.value.providerType,
  (pt) => {
    if (skipWatch.value) {
      skipWatch.value = false;
      return;
    }
    const type = pt as ProviderType;
    form.value.apiBaseUrl = PROVIDER_BASE_URLS[type] || null;
    form.value.maxTokens = DEFAULT_MAX_TOKENS[type] ?? 4096;
    const models = DEFAULT_MODELS[type];
    if (models.length > 0) {
      form.value.model = models[0];
    } else {
      form.value.model = "";
    }
    form.value.name = PROVIDER_NAMES[type] ?? pt;
  },
);

onMounted(() => {
  aiStore.loadProviders();
});

function resetForm() {
  form.value = {
    name: "OpenAI",
    providerType: "openai",
    apiKey: null,
    apiBaseUrl: "https://api.openai.com",
    model: "gpt-4o",
    maxTokens: 4096,
    temperature: 0.7,
    isDefault: false,
  };
  editingId.value = null;
  testResult.value = null;
}

function openAdd() {
  resetForm();
  showForm.value = true;
}

async function openEdit(id: string) {
  const p = aiStore.providers.find((p) => p.id === id);
  if (!p) return;

  // Fetch decrypted API key
  let apiKey = "";
  try {
    apiKey = await tauriInvoke<string>("ai_provider_get_key", { providerId: id });
  } catch { /* ignore */ }

  skipWatch.value = true;
  form.value = {
    name: p.name,
    providerType: p.providerType,
    apiKey,
    apiBaseUrl: p.apiBaseUrl,
    model: p.model,
    maxTokens: p.maxTokens,
    temperature: p.temperature,
    isDefault: p.isDefault,
  };
  editingId.value = id;
  testResult.value = null;
  showForm.value = true;
}

async function save() {
  if (!form.value.name || !form.value.model) return;
  try {
    const isFirst = aiStore.providers.length === 0;
    if (isFirst) {
      form.value.isDefault = true;
    }
    if (editingId.value) {
      await aiStore.updateProvider(editingId.value, form.value);
    } else {
      await aiStore.addProvider(form.value);
    }
    showForm.value = false;
    resetForm();
  } catch (e) {
    testResult.value = { ok: false, msg: String(e) };
  }
}

async function remove(id: string) {
  try {
    await ElMessageBox.confirm(
      t("aiConfig.deleteConfirm"),
      t("context.delete"),
      { type: "warning" },
    );
    await aiStore.deleteProvider(id);
  } catch {
    /* cancelled */
  }
}

async function setDefault(id: string) {
  await aiStore.setDefault(id);
}

async function testConnection() {
  testing.value = true;
  testResult.value = null;
  try {
    if (editingId.value) {
      // Test saved provider
      await tauriInvoke("ai_provider_test", { id: editingId.value });
    } else {
      // Test with form data directly (for new unsaved providers)
      await tauriInvoke("ai_provider_test_direct", {
        providerType: form.value.providerType,
        apiKey: form.value.apiKey ?? "",
        apiBaseUrl: form.value.apiBaseUrl,
        model: form.value.model,
      });
    }
    testResult.value = { ok: true, msg: t("aiConfig.testSuccess") };
  } catch (e) {
    testResult.value = { ok: false, msg: String(e) };
  } finally {
    testing.value = false;
  }
}
</script>

<template>
  <div class="space-y-4">
    <div class="flex items-center justify-between">
      <h3 class="text-sm font-medium" style="color: var(--tm-text-primary)">
        {{ t("settings.aiConfig") }}
      </h3>
      <el-button size="small" :icon="Plus" @click="openAdd">
        {{ t("aiConfig.addProvider") }}
      </el-button>
    </div>

    <!-- Provider list -->
    <div v-if="aiStore.providers.length > 0" class="space-y-1.5">
      <div
        v-for="p in aiStore.providers"
        :key="p.id"
        class="flex items-center gap-2 px-2.5 py-2 rounded transition-colors"
        style="border: 1px solid var(--tm-border)"
      >
        <span
          class="w-1.5 h-1.5 rounded-full shrink-0"
          :class="p.isDefault ? 'bg-green-500' : 'bg-gray-500'"
        />
        <div class="flex-1 min-w-0">
          <div class="text-xs truncate" style="color: var(--tm-text-primary)">
            {{ p.name }}
          </div>
          <div class="text-[10px]" style="color: var(--tm-text-muted)">
            {{ PROVIDER_NAMES[p.providerType] || p.providerType }} · {{ p.model }}
          </div>
        </div>
        <button
          v-if="!p.isDefault"
          class="text-[10px] hover:text-primary-400 transition-colors"
          style="color: var(--tm-text-muted)"
          @click="setDefault(p.id)"
        >
          {{ t("aiConfig.setDefault") }}
        </button>
        <span v-else class="text-[10px] text-green-500">{{
          t("aiConfig.default")
        }}</span>
        <button
          class="text-xs transition-colors"
          style="color: var(--tm-text-secondary)"
          @click="openEdit(p.id)"
        >
          {{ t("context.edit") }}
        </button>
        <el-icon
          :size="12"
          class="hover:text-red-400 cursor-pointer transition-colors shrink-0"
          style="color: var(--tm-text-muted)"
          @click="remove(p.id)"
        >
          <Delete />
        </el-icon>
      </div>
    </div>
    <div
      v-else-if="!showForm"
      class="text-xs py-4 text-center"
      style="color: var(--tm-text-muted)"
    >
      {{ t("aiConfig.noProviders") }}
    </div>

    <!-- Add/Edit form -->
    <div
      v-if="showForm"
      class="space-y-3 pt-2"
      style="border-top: 1px solid var(--tm-border)"
    >
      <!-- Provider type -->
      <div>
        <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
          {{ t("aiConfig.providerType") }}
        </label>
        <el-select v-model="form.providerType" size="small" class="w-full">
          <el-option
            v-for="pt in ALL_PROVIDERS"
            :key="pt.value"
            :label="pt.label"
            :value="pt.value"
          />
        </el-select>
      </div>

      <!-- Name -->
      <div>
        <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
          {{ t("aiConfig.providerName") }}
        </label>
        <el-input v-model="form.name" size="small" />
      </div>

      <!-- API Key -->
      <div v-if="form.providerType !== 'ollama'">
        <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
          API Key
        </label>
        <el-input
          v-model="form.apiKey"
          size="small"
          type="password"
          show-password
          placeholder="sk-..."
        />
      </div>

      <!-- Model & Max Tokens -->
      <div class="flex gap-2">
        <div class="flex-1">
          <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
            {{ t("aiConfig.model") }}
          </label>
          <el-select
            v-if="currentModels.length > 0"
            v-model="form.model"
            size="small"
            class="w-full"
            filterable
            allow-create
          >
            <el-option
              v-for="m in currentModels"
              :key="m"
              :label="m"
              :value="m"
            />
          </el-select>
          <el-input
            v-else
            v-model="form.model"
            size="small"
            placeholder="model-name"
          />
        </div>
        <div class="w-28 shrink-0">
          <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
            Max Tokens
          </label>
          <el-input-number
            v-model="form.maxTokens"
            size="small"
            :min="64"
            :max="128000"
            :step="1024"
            controls-position="right"
            class="!w-full"
          />
        </div>
      </div>

      <!-- Base URL -->
      <div>
        <label class="text-xs mb-1 block" style="color: var(--tm-text-secondary)">
          API Base URL
          <span class="text-[10px] ml-1" style="color: var(--tm-text-muted)">
            ({{ currentBaseUrl || "custom" }})
          </span>
        </label>
        <el-input v-model="form.apiBaseUrl" size="small" :placeholder="currentBaseUrl" />
      </div>

      <!-- Temperature slider -->
      <div>
        <div class="flex items-center justify-between mb-1">
          <label class="text-xs" style="color: var(--tm-text-secondary)">
            Temperature
          </label>
          <span class="text-xs" style="color: var(--tm-text-muted)">{{ form.temperature }}</span>
        </div>
        <el-slider
          v-model="form.temperature"
          :min="0"
          :max="2"
          :step="0.1"
          :show-tooltip="false"
        />
      </div>

      <!-- Test result inline -->
      <div
        v-if="testResult"
        class="text-xs px-2 py-1.5 rounded"
        :class="testResult.ok ? 'text-green-500' : 'text-red-400'"
        style="background: var(--tm-bg-hover)"
      >
        {{ testResult.msg }}
      </div>

      <div class="flex justify-end gap-2">
        <el-button
          size="small"
          :loading="testing"
          @click="testConnection"
        >
          {{ t("aiConfig.test") }}
        </el-button>
        <el-button size="small" @click="showForm = false">
          {{ t("connection.cancel") }}
        </el-button>
        <el-button size="small" type="primary" @click="save">
          {{ t("connection.save") }}
        </el-button>
      </div>
    </div>
  </div>
</template>
