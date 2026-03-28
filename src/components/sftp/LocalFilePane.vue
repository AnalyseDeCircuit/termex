<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { tauriInvoke } from "@/utils/tauri";
import { Folder, Document, ArrowUp, RefreshRight } from "@element-plus/icons-vue";

const { t } = useI18n();

interface LocalEntry {
  name: string;
  isDir: boolean;
  size: number;
}

const currentPath = ref("");
const entries = ref<LocalEntry[]>([]);
const loading = ref(false);

onMounted(async () => {
  try {
    const home = await tauriInvoke<string>("local_home_dir");
    currentPath.value = home;
    await listDir(home);
  } catch {
    currentPath.value = "/";
    await listDir("/");
  }
});

async function listDir(path: string) {
  loading.value = true;
  try {
    const result = await tauriInvoke<LocalEntry[]>("local_list_dir", { path });
    entries.value = result;
    currentPath.value = path;
  } catch {
    entries.value = [];
  } finally {
    loading.value = false;
  }
}

async function enterDir(name: string) {
  const sep = currentPath.value.endsWith("/") ? "" : "/";
  await listDir(`${currentPath.value}${sep}${name}`);
}

async function goUp() {
  const parts = currentPath.value.replace(/\/+$/, "").split("/");
  parts.pop();
  const parent = parts.join("/") || "/";
  await listDir(parent);
}

const breadcrumbs = computed(() => {
  const parts = currentPath.value.split("/").filter(Boolean);
  const items = [{ name: "/", path: "/" }];
  let acc = "";
  for (const part of parts) {
    acc += `/${part}`;
    items.push({ name: part, path: acc });
  }
  return items;
});

function handleDblClick(entry: LocalEntry) {
  if (entry.isDir) enterDir(entry.name);
}
</script>

<template>
  <div class="flex flex-col h-full min-w-0">
    <!-- Toolbar -->
    <div class="flex items-center gap-1 px-2 py-1 shrink-0" style="border-bottom: 1px solid var(--tm-border)">
      <span class="text-[10px] font-medium px-1" style="color: var(--tm-text-muted)">{{ t("sftp.local") }}</span>
      <button class="tm-icon-btn p-0.5 rounded" @click="goUp">
        <el-icon :size="12"><ArrowUp /></el-icon>
      </button>
      <button class="tm-icon-btn p-0.5 rounded" @click="listDir(currentPath)">
        <el-icon :size="12"><RefreshRight /></el-icon>
      </button>
      <!-- Breadcrumb -->
      <div class="flex-1 flex items-center text-[10px] overflow-hidden ml-1" style="color: var(--tm-text-muted)">
        <template v-for="(item, idx) in breadcrumbs" :key="item.path">
          <span v-if="idx > 0" class="mx-0.5">/</span>
          <button class="truncate px-0.5 rounded hover:bg-white/5" style="color: var(--tm-text-secondary)" @click="listDir(item.path)">
            {{ item.name }}
          </button>
        </template>
      </div>
    </div>

    <!-- File list -->
    <div class="flex-1 overflow-auto text-xs">
      <div
        v-for="entry in entries"
        :key="entry.name"
        class="tm-tree-item flex items-center gap-1.5 px-2 py-1 cursor-default"
        @dblclick="handleDblClick(entry)"
      >
        <el-icon :size="12" class="shrink-0">
          <Folder v-if="entry.isDir" class="text-yellow-500" />
          <Document v-else style="color: var(--tm-text-muted)" />
        </el-icon>
        <span class="truncate">{{ entry.name }}</span>
      </div>
      <div v-if="!loading && entries.length === 0" class="text-center py-4" style="color: var(--tm-text-muted)">
        {{ t("sftp.empty") }}
      </div>
    </div>
  </div>
</template>
