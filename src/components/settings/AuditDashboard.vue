<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";

const { t } = useI18n();

interface AuditEntry {
  id: number;
  timestamp: string;
  eventType: string;
  detail: string | null;
}

interface AuditSummary {
  total: number;
  connections: number;
  credentialAccess: number;
  configChanges: number;
  memberOps: number;
}

const summary = ref<AuditSummary>({ total: 0, connections: 0, credentialAccess: 0, configChanges: 0, memberOps: 0 });
const entries = ref<AuditEntry[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = 20;
const filterType = ref("");
const loading = ref(false);
const exporting = ref(false);

const dateRange = ref<"month" | "week" | "all">("month");

const dateParams = computed(() => {
  const now = new Date();
  if (dateRange.value === "week") {
    const d = new Date(now);
    d.setDate(d.getDate() - 7);
    return { startDate: d.toISOString(), endDate: now.toISOString() };
  }
  if (dateRange.value === "month") {
    const d = new Date(now);
    d.setMonth(d.getMonth() - 1);
    return { startDate: d.toISOString(), endDate: now.toISOString() };
  }
  return { startDate: null, endDate: null };
});

async function loadSummary() {
  try {
    summary.value = await tauriInvoke<AuditSummary>("audit_log_summary", dateParams.value);
  } catch { /* ignore */ }
}

async function loadEntries() {
  loading.value = true;
  try {
    const result = await tauriInvoke<{ items: AuditEntry[]; total: number }>(
      "audit_log_list",
      {
        eventType: filterType.value || null,
        startDate: dateParams.value.startDate,
        endDate: dateParams.value.endDate,
        limit: pageSize,
        offset: (page.value - 1) * pageSize,
      },
    );
    entries.value = result.items;
    total.value = result.total;
  } finally {
    loading.value = false;
  }
}

async function refresh() {
  page.value = 1;
  await Promise.all([loadSummary(), loadEntries()]);
}

async function onPageChange(p: number) {
  page.value = p;
  await loadEntries();
}

async function onFilterChange() {
  page.value = 1;
  await loadEntries();
}

async function onDateChange() {
  await refresh();
}

async function exportReport(format: string) {
  exporting.value = true;
  try {
    const filePath = await tauriInvoke<string>("save_file_dialog", {
      title: "Export Audit Report",
      defaultName: `audit-report.${format}`,
    });
    if (!filePath) return;

    const { startDate, endDate } = dateParams.value;
    await tauriInvoke("audit_export_report", {
      filePath,
      startDate: startDate ?? "2020-01-01T00:00:00Z",
      endDate: endDate ?? new Date().toISOString(),
      eventTypes: filterType.value ? [filterType.value] : null,
      format,
    });
    ElMessage.success(`Report exported: ${filePath}`);
  } catch (err) {
    ElMessage.error(String(err));
  } finally {
    exporting.value = false;
  }
}

function formatTs(ts: string): string {
  try {
    const d = new Date(ts);
    return d.toLocaleString(undefined, {
      month: "short", day: "numeric",
      hour: "2-digit", minute: "2-digit",
    });
  } catch {
    return ts.substring(0, 16);
  }
}

function eventLabel(et: string): string {
  return et.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

const totalPages = computed(() => Math.ceil(total.value / pageSize));

onMounted(refresh);
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Header -->
    <div class="flex items-center justify-between">
      <span class="text-xs font-medium" style="color: var(--tm-text-secondary)">
        {{ t("teamV2.auditDashboard") }}
      </span>
      <div class="flex items-center gap-1">
        <!-- Date range -->
        <select
          v-model="dateRange"
          class="text-[10px] px-1.5 py-0.5 rounded border-0 outline-none"
          style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
          @change="onDateChange"
        >
          <option value="week">{{ t("teamV2.auditThisWeek") }}</option>
          <option value="month">{{ t("teamV2.auditThisMonth") }}</option>
          <option value="all">{{ t("teamV2.auditAll") }}</option>
        </select>
        <!-- Export -->
        <select
          class="text-[10px] px-1.5 py-0.5 rounded border-0 outline-none"
          style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
          @change="(e: Event) => { const v = (e.target as HTMLSelectElement).value; if (v) exportReport(v); (e.target as HTMLSelectElement).value = ''; }"
        >
          <option value="">{{ t("teamV2.auditExportReport") }}</option>
          <option value="json">JSON</option>
          <option value="csv">CSV</option>
          <option value="html">HTML</option>
        </select>
      </div>
    </div>

    <!-- Summary cards -->
    <div class="grid grid-cols-4 gap-2">
      <div
        v-for="card in [
          { label: t('teamV2.auditConnections'), value: summary.connections },
          { label: t('teamV2.auditCredAccess'), value: summary.credentialAccess },
          { label: t('teamV2.auditConfigChanges'), value: summary.configChanges },
          { label: t('teamV2.auditMemberOps'), value: summary.memberOps },
        ]"
        :key="card.label"
        class="text-center px-2 py-2 rounded"
        style="background: var(--tm-bg-secondary)"
      >
        <div class="text-sm font-bold" style="color: var(--tm-text-primary)">{{ card.value }}</div>
        <div class="text-[10px]" style="color: var(--tm-text-muted)">{{ card.label }}</div>
      </div>
    </div>

    <!-- Filter -->
    <div class="flex items-center gap-2">
      <span class="text-[10px]" style="color: var(--tm-text-muted)">{{ t("teamV2.auditRecentOps") }}</span>
      <select
        v-model="filterType"
        class="ml-auto text-[10px] px-1.5 py-0.5 rounded border-0 outline-none"
        style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
        @change="onFilterChange"
      >
        <option value="">{{ t("teamV2.auditFilterAll") }}</option>
        <option value="ssh_connect_success">SSH Connect</option>
        <option value="credential_accessed">Credential Access</option>
        <option value="server_created">Server Created</option>
        <option value="server_deleted">Server Deleted</option>
        <option value="team_sync">Team Sync</option>
        <option value="team_member_role_change">Role Change</option>
        <option value="team_member_remove">Member Remove</option>
        <option value="team_key_rotated">Key Rotated</option>
      </select>
    </div>

    <!-- Entry list -->
    <div
      class="flex flex-col gap-0.5 max-h-[200px] overflow-y-auto"
      :class="{ 'animate-pulse': loading }"
    >
      <div v-if="entries.length === 0" class="text-xs py-4 text-center" style="color: var(--tm-text-muted)">
        No audit entries
      </div>
      <div
        v-for="entry in entries"
        :key="entry.id"
        class="flex items-center gap-2 px-2 py-1 rounded text-[11px]"
        style="background: var(--tm-bg-secondary)"
      >
        <span class="shrink-0 w-[90px]" style="color: var(--tm-text-muted)">{{ formatTs(entry.timestamp) }}</span>
        <span class="shrink-0 w-[120px] truncate" style="color: var(--tm-text-primary)">{{ eventLabel(entry.eventType) }}</span>
        <span class="flex-1 truncate" style="color: var(--tm-text-muted)">{{ entry.detail ?? "-" }}</span>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="totalPages > 1" class="flex items-center justify-center gap-1">
      <button
        class="text-[10px] px-2 py-0.5 rounded"
        :disabled="page <= 1"
        style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
        @click="onPageChange(page - 1)"
      >
        &laquo;
      </button>
      <span class="text-[10px]" style="color: var(--tm-text-muted)">
        {{ page }} / {{ totalPages }}
      </span>
      <button
        class="text-[10px] px-2 py-0.5 rounded"
        :disabled="page >= totalPages"
        style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
        @click="onPageChange(page + 1)"
      >
        &raquo;
      </button>
    </div>
  </div>
</template>
