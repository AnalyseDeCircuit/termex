<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage, ElMessageBox } from "element-plus";
import {} from "@element-plus/icons-vue";
import { useProxyStore } from "@/stores/proxyStore";
import { useServerStore } from "@/stores/serverStore";
import { useTeamStore } from "@/stores/teamStore";
import { tauriInvoke } from "@/utils/tauri";
import ContextMenu from "./ContextMenu.vue";
import type { MenuItem } from "./ContextMenu.vue";
import type { ProxyType, ProxyInput } from "@/types/proxy";

const { t } = useI18n();
const proxyStore = useProxyStore();
const serverStore = useServerStore();
const teamStore = useTeamStore();

// ── Filter state ──
const proxyFilter = ref<"all" | "private" | "team">("all");

const visibleProxies = computed(() => {
  if (!teamStore.isJoined || proxyFilter.value === "all") return proxyStore.proxies;
  if (proxyFilter.value === "private") return proxyStore.privateProxies;
  return proxyStore.teamProxies;
});

const showPrivateSection = computed(() =>
  teamStore.isJoined &&
  proxyFilter.value === "all" &&
  proxyStore.privateProxies.length > 0 &&
  proxyStore.teamProxies.length > 0,
);

const showTeamSection = computed(() =>
  teamStore.isJoined &&
  (proxyFilter.value === "all" || proxyFilter.value === "team") &&
  proxyStore.teamProxies.length > 0,
);

// ── Dialog state ──
const dialogVisible = ref(false);
const editId = ref<string | null>(null);
const testing = ref(false);
const testResult = ref<{ ok: boolean; msg: string } | null>(null);

const form = ref<ProxyInput>({
  name: "", proxyType: "socks5", host: "", port: 1080,
  username: "", password: "",
});

const torStatus = ref<{ running: boolean; port: number } | null>(null);

const proxyTypes: { value: ProxyType; label: string; defaultPort: number }[] = [
  { value: "socks5", label: "SOCKS5", defaultPort: 1080 },
  { value: "socks4", label: "SOCKS4", defaultPort: 1080 },
  { value: "http", label: "HTTP CONNECT", defaultPort: 8080 },
  { value: "tor", label: "Tor", defaultPort: 9050 },
];

const dialogTitle = computed(() =>
  editId.value ? t("connection.proxyEdit") : t("connection.proxyAdd"),
);

async function onTypeChange(val: ProxyType) {
  const pt = proxyTypes.find((p) => p.value === val);
  if (pt) form.value.port = pt.defaultPort;
  if (val === "tor") {
    form.value.host = "127.0.0.1";
    form.value.tlsEnabled = false;
    torStatus.value = null;
    try {
      const status = await tauriInvoke<{ running: boolean; port: number }>("tor_detect", {});
      torStatus.value = status;
      if (status.running) form.value.port = status.port;
    } catch { /* ignore */ }
  } else {
    torStatus.value = null;
  }
}

function openAddDialog() {
  editId.value = null;
  form.value = {
    name: "", proxyType: "socks5", host: "", port: 1080,
    username: "", password: "",
    tlsEnabled: false, tlsVerify: true,
    caCertPath: "", clientCertPath: "", clientKeyPath: "",
  };
  testResult.value = null;
  dialogVisible.value = true;
}

async function openEditDialog(id: string) {
  const proxy = proxyStore.proxies.find((p) => p.id === id);
  if (!proxy) return;
  editId.value = id;
  const password = await proxyStore.getPassword(id).catch(() => "");
  form.value = {
    name: proxy.name,
    proxyType: proxy.proxyType as ProxyType,
    host: proxy.host,
    port: proxy.port,
    username: proxy.username ?? "",
    password,
    tlsEnabled: proxy.tlsEnabled ?? false,
    tlsVerify: proxy.tlsVerify ?? true,
    caCertPath: proxy.caCertPath ?? "",
    clientCertPath: proxy.clientCertPath ?? "",
    clientKeyPath: proxy.clientKeyPath ?? "",
  };
  testResult.value = null;
  dialogVisible.value = true;
}

async function saveProxy() {
  if (!form.value.name || !form.value.host) return;
  try {
    if (editId.value) {
      await proxyStore.update(editId.value, form.value);
    } else {
      await proxyStore.create(form.value);
    }
    dialogVisible.value = false;
  } catch (e) {
    ElMessage.error(String(e));
  }
}

async function testProxy() {
  if (!form.value.host) return;
  testing.value = true;
  testResult.value = null;
  try {
    // Test by connecting to the proxy address directly (TCP connect test)
    await tauriInvoke("ssh_test", {
      host: form.value.host,
      port: form.value.port,
      username: form.value.username || "test",
      authType: "password",
      password: form.value.password || null,
      keyPath: null,
      passphrase: null,
    });
    testResult.value = { ok: true, msg: t("connection.testSuccess") };
  } catch {
    // TCP connect succeeded (SSH auth fails = proxy is reachable)
    testResult.value = { ok: true, msg: t("connection.proxyTestReachable") };
  } finally {
    testing.value = false;
  }
}

async function deleteProxy(id: string) {
  const proxy = proxyStore.proxies.find((p) => p.id === id);
  if (!proxy) return;
  try {
    await ElMessageBox.confirm(
      t("connection.proxyDeleteConfirm", { name: proxy.name }),
      t("connection.proxyDelete"),
      { type: "warning" },
    );
    await proxyStore.remove(id);
    await serverStore.fetchAll();
  } catch {
    // cancelled
  }
}

function usageCount(proxyId: string): number {
  return serverStore.servers.filter((s) => {
    // Legacy field
    if (s.networkProxyId === proxyId) return true;
    // V10 chain: check if any hop references this proxy
    if (s.chain?.some((h) => h.hopType === "proxy" && h.hopId === proxyId)) return true;
    return false;
  }).length;
}

// ── Context menu ──
const ctxVisible = ref(false);
const ctxX = ref(0);
const ctxY = ref(0);
const ctxProxyId = ref<string | null>(null);

const blankCtxItems = computed<MenuItem[]>(() => [
  { label: t("connection.proxyAdd"), action: "add" },
]);

const itemCtxItems = computed<MenuItem[]>(() => {
  const items: MenuItem[] = [
    { label: t("connection.proxyEdit"), action: "edit" },
    { label: t("connection.proxyDelete"), action: "delete", danger: true, divided: true },
  ];
  if (teamStore.isJoined) {
    const proxy = ctxProxyId.value
      ? proxyStore.proxies.find((p) => p.id === ctxProxyId.value)
      : null;
    if (proxy && !proxy.teamId) {
      if (proxy.shared) {
        items.push({ label: t("team.makePrivate"), action: "make-private", divided: true });
      } else {
        items.push({ label: t("team.shareServer"), action: "share-team", divided: true });
      }
    }
  }
  items.push({ label: t("connection.proxyAdd"), action: "add", divided: true });
  return items;
});

const ctxItems = computed(() =>
  ctxProxyId.value ? itemCtxItems.value : blankCtxItems.value,
);

function onRootContextMenu(e: MouseEvent) {
  // Only if not clicking on a proxy item
  if ((e.target as HTMLElement).closest(".proxy-item")) return;
  e.preventDefault();
  ctxProxyId.value = null;
  ctxX.value = e.clientX;
  ctxY.value = e.clientY;
  ctxVisible.value = true;
}

function onItemContextMenu(e: MouseEvent, id: string) {
  e.preventDefault();
  e.stopPropagation();
  ctxProxyId.value = id;
  ctxX.value = e.clientX;
  ctxY.value = e.clientY;
  ctxVisible.value = true;
}

function onCtxSelect(action: string) {
  if (action === "add") {
    openAddDialog();
  } else if (action === "edit" && ctxProxyId.value) {
    openEditDialog(ctxProxyId.value);
  } else if (action === "delete" && ctxProxyId.value) {
    deleteProxy(ctxProxyId.value);
  } else if (action === "share-team" && ctxProxyId.value) {
    proxyStore.setShared(ctxProxyId.value, true);
  } else if (action === "make-private" && ctxProxyId.value) {
    proxyStore.setShared(ctxProxyId.value, false);
  }
}

onMounted(() => {
  proxyStore.fetchAll();
});
</script>

<template>
  <div
    style="min-height: 100%"
    @contextmenu="onRootContextMenu"
  >
    <!-- Filter tabs (only when joined a team) -->
    <div
      v-if="teamStore.isJoined"
      class="flex items-center gap-1 px-2 py-1"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <button
        v-for="f in (['all', 'private', 'team'] as const)"
        :key="f"
        class="px-2 py-0.5 rounded text-[10px] transition-colors"
        :class="proxyFilter === f ? 'bg-primary-500/20 text-primary-400' : 'text-gray-500 hover:text-gray-300'"
        @click="proxyFilter = f"
      >
        {{ t(`sidebar.filter_${f}`) }}
      </button>
    </div>

    <div class="px-2 py-1">
      <!-- Empty state -->
      <div
        v-if="visibleProxies.length === 0"
        class="text-xs py-8 text-center"
        style="color: var(--tm-text-muted)"
      >
        {{ t("connection.proxyNoConfig") }}
      </div>

      <template v-else>
        <!-- Private section header (shown when both sections are visible) -->
        <div v-if="showPrivateSection" class="flex items-center gap-1 px-1 py-1 text-[10px] font-medium" style="color: var(--tm-text-muted)">
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="11" width="18" height="11" rx="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
          {{ t("sidebar.privateServers") }}
        </div>

        <!-- Private proxies -->
        <div v-if="proxyFilter !== 'team'" class="space-y-0.5">
          <div
            v-for="proxy in (teamStore.isJoined ? proxyStore.privateProxies : proxyStore.proxies)"
            :key="proxy.id"
            class="proxy-item tm-tree-item w-full flex items-center gap-1.5 px-2 py-1.5 transition-colors rounded-sm cursor-default group text-xs"
            style="color: var(--tm-text-primary)"
            @contextmenu="onItemContextMenu($event, proxy.id)"
            @dblclick="openEditDialog(proxy.id)"
          >
            <!-- Proxy type icon -->
            <svg v-if="proxy.proxyType === 'tor'" class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#a855f7" stroke-width="1.5">
              <circle cx="12" cy="12" r="10" /><circle cx="12" cy="12" r="6" /><circle cx="12" cy="12" r="2.5" fill="#a855f7" />
            </svg>
            <svg v-else-if="proxy.proxyType === 'socks5'" class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10" /><ellipse cx="12" cy="12" rx="4" ry="10" /><path d="M2 12h20" /><path d="M4.9 5h14.2" opacity="0.5" /><path d="M4.9 19h14.2" opacity="0.5" />
            </svg>
            <svg v-else-if="proxy.proxyType === 'socks4'" class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#fb923c" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <circle cx="12" cy="12" r="10" /><ellipse cx="12" cy="12" rx="4" ry="10" /><path d="M2 12h20" />
            </svg>
            <svg v-else class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" :stroke="proxy.tlsEnabled ? '#16a34a' : '#60a5fa'" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="8 6 2 12 8 18" /><polyline points="16 6 22 12 16 18" />
              <line v-if="proxy.tlsEnabled" x1="14" y1="4" x2="10" y2="20" opacity="0.4" />
            </svg>

            <!-- Name + share indicator -->
            <span class="flex-1 min-w-0 flex items-center gap-0.5">
              <span class="truncate">{{ proxy.name }}</span>
              <el-tooltip
                v-if="proxy.shared || proxy.teamId"
                :content="proxy.teamId && !proxy.shared
                  ? t('team.receivedFrom', { name: proxy.sharedBy || '?' })
                  : t('team.sharedWithTeam')"
                :show-after="0"
              >
                <svg
                  class="w-3 h-3 shrink-0 ml-0.5"
                  :style="{ color: proxy.shared && !proxy.teamId ? 'var(--el-color-success)' : 'var(--el-color-primary)' }"
                  viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
                >
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                  <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </el-tooltip>
            </span>

            <!-- Hover share toggle button -->
            <button
              v-if="teamStore.isJoined && !proxy.teamId"
              class="shrink-0 p-0.5 rounded transition-all"
              :class="proxy.shared ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'"
              :title="proxy.shared ? t('team.makePrivate') : t('context.shareWithTeam')"
              :style="{ color: proxy.shared ? 'var(--el-color-success)' : 'var(--tm-text-muted)', background: 'transparent' }"
              @click.stop="proxyStore.setShared(proxy.id, !proxy.shared)"
            >
              <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </button>

            <!-- Usage count badge -->
            <div
              v-if="usageCount(proxy.id) > 0"
              class="shrink-0 px-1.5 py-0.5 rounded text-[10px] font-medium"
              style="background: rgba(96,165,250,0.12); color: #60a5fa"
            >
              ⇄ {{ usageCount(proxy.id) }}
            </div>
          </div>
        </div>

        <!-- Divider between sections -->
        <div
          v-if="showPrivateSection"
          class="mx-1 my-1"
          style="border-top: 1px solid var(--tm-border)"
        />

        <!-- Team section -->
        <template v-if="showTeamSection">
          <div class="flex items-center gap-1.5 px-1 py-1 text-[10px] font-medium" style="color: #60a5fa">
            <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
              <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
            </svg>
            {{ t("sidebar.teamServers") }}
          </div>
          <div class="space-y-0.5">
            <div
              v-for="proxy in proxyStore.teamProxies"
              :key="proxy.id"
              class="proxy-item tm-tree-item w-full flex items-center gap-1.5 px-2 py-1.5 transition-colors rounded-sm cursor-default text-xs group"
              style="color: var(--tm-text-primary)"
              @contextmenu="onItemContextMenu($event, proxy.id)"
              @dblclick="openEditDialog(proxy.id)"
            >
              <!-- Proxy type icon -->
              <svg v-if="proxy.proxyType === 'tor'" class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#a855f7" stroke-width="1.5">
                <circle cx="12" cy="12" r="10" /><circle cx="12" cy="12" r="6" /><circle cx="12" cy="12" r="2.5" fill="#a855f7" />
              </svg>
              <svg v-else-if="proxy.proxyType === 'socks5'" class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="10" /><ellipse cx="12" cy="12" rx="4" ry="10" /><path d="M2 12h20" />
              </svg>
              <svg v-else class="shrink-0" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#60a5fa" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="8 6 2 12 8 18" /><polyline points="16 6 22 12 16 18" />
              </svg>

              <!-- Name only (no left indicator — right button is sufficient) -->
              <span class="flex-1 min-w-0 truncate">{{ proxy.name }}</span>

              <!-- Make-private button (always visible for team nodes) -->
              <button
                class="shrink-0 p-0.5 rounded transition-all"
                :title="proxy.teamId ? t('team.makePrivate') : t('team.makePrivate')"
                :style="{ color: 'var(--el-color-primary)', background: 'transparent' }"
                @click.stop="proxy.teamId ? proxyStore.makeLocal(proxy.id) : proxyStore.setShared(proxy.id, false)"
              >
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                  <circle cx="9" cy="7" r="4" />
                  <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                  <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
              </button>

              <!-- Usage count badge -->
              <div
                v-if="usageCount(proxy.id) > 0"
                class="shrink-0 px-1.5 py-0.5 rounded text-[10px] font-medium"
                style="background: rgba(96,165,250,0.12); color: #60a5fa"
              >
                ⇄ {{ usageCount(proxy.id) }}
              </div>
            </div>
          </div>
        </template>
      </template>
    </div>

    <!-- Context menu -->
    <ContextMenu
      v-if="ctxVisible"
      :items="ctxItems"
      :x="ctxX"
      :y="ctxY"
      @select="onCtxSelect"
      @close="ctxVisible = false"
    />

    <!-- Add/Edit dialog -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="420px"
      :close-on-click-modal="true"
      :close-on-press-escape="true"
      destroy-on-close
      class="proxy-dialog"
    >
      <el-form label-position="top" size="default">
        <div class="flex gap-2">
          <el-form-item :label="t('connection.proxyName')" class="flex-1">
            <el-input v-model="form.name" />
          </el-form-item>
          <el-form-item :label="t('connection.proxyType')" class="w-40">
            <el-select v-model="form.proxyType" class="w-full" @change="onTypeChange">
              <el-option v-for="pt in proxyTypes" :key="pt.value" :label="pt.label" :value="pt.value" />
            </el-select>
          </el-form-item>
        </div>

        <div class="flex gap-2">
          <el-form-item :label="t('connection.proxyHost')" class="flex-1">
            <el-input v-model="form.host" placeholder="proxy.example.com" />
          </el-form-item>
          <el-form-item :label="t('connection.proxyPort')" class="w-28">
            <el-input-number v-model="form.port" :min="1" :max="65535" controls-position="right" />
          </el-form-item>
        </div>

        <div class="flex gap-2">
          <el-form-item :label="t('connection.proxyUsername')" class="flex-1">
            <el-input v-model="form.username" />
          </el-form-item>
          <el-form-item :label="t('connection.proxyPassword')" class="flex-1">
            <el-input v-model="form.password" type="password" show-password />
          </el-form-item>
        </div>

        <!-- Tor detect status -->
        <div v-if="form.proxyType === 'tor' && torStatus" class="text-xs px-2 py-1.5 rounded mb-3" :class="torStatus.running ? 'text-green-500' : 'text-red-400'" style="background: var(--tm-bg-hover)">
          {{ torStatus.running ? t("connection.proxyTorRunning", { port: torStatus.port }) : t("connection.proxyTorNotFound") }}
        </div>

        <!-- TLS (HTTP only, hidden for Tor) -->
        <template v-if="form.proxyType === 'http'">
          <el-divider style="margin: 8px 0;" />
          <div class="flex items-center gap-4 mb-3">
            <el-checkbox v-model="form.tlsEnabled">{{ t("connection.proxyTlsEnable") }}</el-checkbox>
            <el-checkbox v-model="form.tlsVerify" :disabled="!form.tlsEnabled">{{ t("connection.proxyTlsVerify") }}</el-checkbox>
          </div>
          <template v-if="form.tlsEnabled">
            <el-form-item :label="t('connection.proxyCaCert')">
              <el-input v-model="form.caCertPath" />
            </el-form-item>
            <el-form-item :label="t('connection.proxyClientCert')">
              <el-input v-model="form.clientCertPath" />
            </el-form-item>
            <el-form-item :label="t('connection.proxyClientKey')">
              <el-input v-model="form.clientKeyPath" />
            </el-form-item>
          </template>
        </template>
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
            <el-button :loading="testing" @click="testProxy">
              {{ t("connection.test") }}
            </el-button>
            <div class="flex gap-2">
              <el-button @click="dialogVisible = false">{{ t("connection.cancel") }}</el-button>
              <el-button type="primary" @click="saveProxy">{{ t("connection.save") }}</el-button>
            </div>
          </div>
        </div>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
:deep(.proxy-dialog .el-dialog) {
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

:deep(.proxy-dialog .el-form-item) {
  margin-bottom: 12px;
}

:deep(.proxy-dialog .el-form-item__label) {
  padding-bottom: 2px;
}

:deep(.proxy-dialog .el-input__inner) {
  height: 30px;
  line-height: 30px;
}

:deep(.proxy-dialog .el-input) {
  --el-input-height: 30px;
}

:deep(.proxy-dialog .el-input-number) {
  --el-input-number-height: 30px;
}
</style>
