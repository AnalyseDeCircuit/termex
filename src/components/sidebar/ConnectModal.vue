<script setup lang="ts">
import { ref, reactive, watch, computed } from "vue";
import { useI18n } from "vue-i18n";
import { useServerStore } from "@/stores/serverStore";
import { useSessionStore } from "@/stores/sessionStore";
import { tauriInvoke } from "@/utils/tauri";
import type { ServerInput } from "@/types/server";

const { t } = useI18n();
const serverStore = useServerStore();
const sessionStore = useSessionStore();

const props = defineProps<{
  visible: boolean;
  editId?: string | null;
}>();

const emit = defineEmits<{
  (e: "update:visible", val: boolean): void;
}>();

const dialogVisible = computed({
  get: () => props.visible,
  set: (val) => emit("update:visible", val),
});

const loading = ref(false);
const testing = ref(false);
const testResult = ref<{ ok: boolean; msg: string } | null>(null);

const form = reactive<ServerInput>({
  name: "",
  host: "",
  port: 22,
  username: "root",
  authType: "password",
  password: "",
  keyPath: "",
  passphrase: "",
  groupId: null,
  startupCmd: "",
  tags: [],
});

const title = computed(() =>
  props.editId ? t("connection.name") : t("sidebar.newConnection"),
);

// Reset form when dialog opens
watch(
  () => props.visible,
  (val) => {
    if (val && !props.editId) {
      resetForm();
    }
    if (val && props.editId) {
      loadServer(props.editId);
    }
  },
);

function resetForm() {
  form.name = "";
  form.host = "";
  form.port = 22;
  form.username = "root";
  form.authType = "password";
  form.password = "";
  form.keyPath = "";
  form.passphrase = "";
  form.groupId = null;
  form.startupCmd = "";
  form.tags = [];
  testResult.value = null;
}

async function loadServer(id: string) {
  const server = serverStore.servers.find((s) => s.id === id);
  if (!server) return;
  form.name = server.name;
  form.host = server.host;
  form.port = server.port;
  form.username = server.username;
  form.authType = server.authType;
  form.keyPath = server.keyPath ?? "";
  form.groupId = server.groupId;
  form.startupCmd = server.startupCmd ?? "";
  form.tags = [...server.tags];

  // Fetch decrypted credentials
  try {
    const creds = await tauriInvoke<{ password: string; passphrase: string }>(
      "server_get_credentials",
      { id },
    );
    form.password = creds.password;
    form.passphrase = creds.passphrase;
  } catch {
    form.password = "";
    form.passphrase = "";
  }
}

async function handleSave() {
  if (!form.host || !form.username) return;

  loading.value = true;
  try {
    // Auto-fill name if empty
    const input: ServerInput = {
      ...form,
      name: form.name || `${form.username}@${form.host}`,
    };

    if (props.editId) {
      await serverStore.updateServer(props.editId, input);
    } else {
      await serverStore.createServer(input);
    }
    dialogVisible.value = false;
  } finally {
    loading.value = false;
  }
}

const fileInputRef = ref<HTMLInputElement | null>(null);

function browseKeyFile() {
  fileInputRef.value?.click();
}

function onKeyFileSelected(event: Event) {
  const input = event.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    form.keyPath = reader.result as string;
  };
  reader.readAsText(file);
  input.value = "";
}

async function handleSaveAndConnect() {
  if (!form.host || !form.username) return;

  loading.value = true;
  testResult.value = null;
  try {
    const input: ServerInput = {
      ...form,
      name: form.name || `${form.username}@${form.host}`,
    };

    let server;
    if (props.editId) {
      server = await serverStore.updateServer(props.editId, input);
    } else {
      server = await serverStore.createServer(input);
    }
    dialogVisible.value = false;
    await sessionStore.connect(server.id, server.name, 80, 24);
  } catch (e) {
    testResult.value = { ok: false, msg: String(e) };
  } finally {
    loading.value = false;
  }
}

async function handleTest() {
  if (!form.host || !form.username) return;
  testing.value = true;
  testResult.value = null;
  try {
    await tauriInvoke("ssh_test", {
      host: form.host,
      port: form.port,
      username: form.username,
      authType: form.authType,
      password: form.password || null,
      keyPath: form.keyPath || null,
      passphrase: form.passphrase || null,
    });
    testResult.value = { ok: true, msg: t("connection.testSuccess") };
  } catch (e) {
    testResult.value = { ok: false, msg: String(e) };
  } finally {
    testing.value = false;
  }
}
</script>

<template>
  <el-dialog
    v-model="dialogVisible"
    :title="title"
    width="480px"
    :close-on-click-modal="true"
    :close-on-press-escape="true"
    destroy-on-close
    class="connect-dialog"
  >
    <el-form label-position="top" size="default">
      <el-form-item :label="t('connection.name')">
        <el-input
          v-model="form.name"
          :placeholder="`${form.username || 'user'}@${form.host || 'hostname'}`"
        />
      </el-form-item>

      <div class="flex gap-3">
        <el-form-item :label="t('connection.host')" class="flex-1" required>
          <el-input v-model="form.host" placeholder="192.168.1.1" />
        </el-form-item>
        <el-form-item :label="t('connection.port')" class="w-24">
          <el-input-number v-model="form.port" :min="1" :max="65535" controls-position="right" />
        </el-form-item>
      </div>

      <el-form-item :label="t('connection.username')" required>
        <el-input v-model="form.username" placeholder="root" />
      </el-form-item>

      <el-form-item :label="t('connection.authType')">
        <el-radio-group v-model="form.authType">
          <el-radio-button value="password">{{ t("connection.password") }}</el-radio-button>
          <el-radio-button value="key">{{ t("connection.privateKey") }}</el-radio-button>
        </el-radio-group>
      </el-form-item>

      <el-form-item v-if="form.authType === 'password'" :label="t('connection.password')">
        <el-input v-model="form.password" type="password" show-password />
      </el-form-item>

      <template v-if="form.authType === 'key'">
        <el-form-item>
          <template #label>
            <div class="flex items-center justify-between w-full">
              <span>{{ t('connection.privateKey') }}</span>
              <button
                type="button"
                class="ml-3 text-[11px] text-primary-400 hover:text-primary-300 transition-colors"
                @click="browseKeyFile"
              >
                {{ t('connection.browseKey') }}
              </button>
              <input
                ref="fileInputRef"
                type="file"
                accept=".pem,.key,.pub,.ppk,*"
                class="hidden"
                @change="onKeyFileSelected"
              />
            </div>
          </template>
          <el-input
            v-model="form.keyPath"
            type="textarea"
            :rows="4"
            placeholder="-----BEGIN RSA PRIVATE KEY-----&#10;...&#10;-----END RSA PRIVATE KEY-----"
            resize="none"
          />
        </el-form-item>
        <el-form-item label="Passphrase">
          <el-input v-model="form.passphrase" type="password" show-password />
        </el-form-item>
      </template>

      <el-form-item :label="t('connection.group')">
        <el-select v-model="form.groupId" clearable class="w-full">
          <el-option
            v-for="group in serverStore.groups"
            :key="group.id"
            :label="group.name"
            :value="group.id"
          />
        </el-select>
      </el-form-item>
    </el-form>

    <template #footer>
      <div>
        <!-- Test result -->
        <div
          v-if="testResult"
          class="text-xs px-2 py-1.5 rounded mb-2"
          :class="testResult.ok ? 'text-green-500' : 'text-red-400'"
          style="background: var(--tm-bg-hover)"
        >
          {{ testResult.msg }}
        </div>
        <div class="flex justify-between">
          <el-button :loading="testing" @click="handleTest">
            {{ t("connection.test") }}
          </el-button>
          <div class="flex gap-2">
            <el-button @click="dialogVisible = false">
              {{ t("connection.cancel") }}
            </el-button>
            <el-button type="default" :loading="loading" @click="handleSave">
              {{ t("connection.save") }}
            </el-button>
            <el-button type="primary" :loading="loading" @click="handleSaveAndConnect">
              {{ t("connection.connect") }}
            </el-button>
          </div>
        </div>
      </div>
    </template>
  </el-dialog>
</template>

<style scoped>
:deep(.connect-dialog .el-dialog) {
  --el-dialog-bg-color: var(--tm-bg-elevated);
  --el-dialog-border-radius: 8px;
  --el-text-color-primary: var(--tm-text-primary);
  --el-text-color-regular: var(--tm-text-primary);
  --el-text-color-secondary: var(--tm-text-secondary);
  --el-text-color-placeholder: var(--tm-text-muted);
  --el-bg-color: var(--tm-bg-elevated);
  --el-bg-color-overlay: var(--tm-bg-elevated);
  --el-fill-color-blank: var(--tm-input-bg);
  --el-fill-color-light: var(--tm-bg-hover);
  --el-border-color: var(--tm-input-border);
  --el-border-color-light: var(--tm-border);
  --el-border-color-lighter: var(--tm-border);
  color: var(--tm-text-primary);
}

:deep(.connect-dialog .el-form-item) {
  margin-bottom: 12px;
}

:deep(.connect-dialog .el-form-item__label) {
  padding-bottom: 2px;
}

:deep(.connect-dialog .el-input__inner) {
  height: 30px;
  line-height: 30px;
}

:deep(.connect-dialog .el-input) {
  --el-input-height: 30px;
}

:deep(.connect-dialog .el-input-number) {
  --el-input-number-height: 30px;
}
</style>
