<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { useI18n } from "vue-i18n";
import { useRecordingStore } from "@/stores/recordingStore";
import { useTeamStore } from "@/stores/teamStore";
import { formatFileSize, formatDuration } from "@/utils/format";
import type { Recording } from "@/types/recording";

const { t } = useI18n();
const recordingStore = useRecordingStore();
const teamStore = useTeamStore();
const loading = ref(false);

// ── Team filter state ──
const recordingFilter = ref<"all" | "private" | "team">("all");

const hasPrivateRecordings = computed(() =>
  recordingStore.recordings.some((r) => !r.shared && !r.teamId),
);
const hasTeamRecordings = computed(() =>
  recordingStore.recordings.some((r) => !!r.shared || !!r.teamId),
);

const showSplitView = computed(() =>
  teamStore.isJoined && recordingFilter.value === "all",
);

const visibleRecordings = computed(() => {
  if (!teamStore.isJoined) return recordingStore.recordings;
  if (recordingFilter.value === "private") return recordingStore.privateRecordings;
  if (recordingFilter.value === "team") return recordingStore.teamRecordings;
  return recordingStore.recordings;
});

// ── Grouped helpers ──
function groupRecordings(list: Recording[]) {
  const groups: Record<string, { serverName: string; recordings: Recording[] }> = {};
  for (const rec of list) {
    if (!groups[rec.serverId]) {
      groups[rec.serverId] = { serverName: rec.serverName, recordings: [] };
    }
    groups[rec.serverId].recordings.push(rec);
  }
  for (const group of Object.values(groups)) {
    group.recordings.sort((a, b) => b.startedAt.localeCompare(a.startedAt));
  }
  return groups;
}

const privateGrouped = computed(() => groupRecordings(recordingStore.privateRecordings));
const teamGrouped = computed(() => groupRecordings(recordingStore.teamRecordings));
const visibleGrouped = computed(() => groupRecordings(visibleRecordings.value));

const totalSize = computed(() =>
  recordingStore.recordings.reduce((sum, r) => sum + r.fileSize, 0),
);

// ── Hover state ──
const hoveredId = ref<string | null>(null);

async function loadData() {
  loading.value = true;
  await recordingStore.loadRecordings();
  loading.value = false;
}

async function handleDelete(rec: Recording) {
  await recordingStore.deleteRecording(rec.id);
}

function playRecording(rec: Recording) {
  window.dispatchEvent(
    new CustomEvent("termex:play-recording", { detail: rec }),
  );
}

async function toggleShare(rec: Recording) {
  await recordingStore.setShared(rec.id, !rec.shared);
}

async function makeLocal(rec: Recording) {
  await recordingStore.makeLocal(rec.id);
}

onMounted(loadData);
</script>

<template>
  <div class="recording-list">
    <!-- Team filter tabs (only when joined) -->
    <div
      v-if="teamStore.isJoined"
      class="flex items-center gap-1 px-2 py-1 shrink-0"
      style="border-bottom: 1px solid var(--tm-border)"
    >
      <button
        v-for="f in (['all', 'private', 'team'] as const)"
        :key="f"
        class="px-2 py-0.5 rounded text-[10px] transition-colors"
        :class="recordingFilter === f ? 'bg-primary-500/20 text-primary-400' : 'text-gray-500 hover:text-gray-300'"
        @click="recordingFilter = f"
      >
        {{ t(`sidebar.filter_${f}`) }}
      </button>
      <span class="ml-auto text-xs" style="color: var(--tm-text-muted)">
        {{ recordingStore.recordings.length }} &middot;
        {{ formatFileSize(totalSize) }}
      </span>
    </div>

    <div v-if="loading" class="recording-list-empty">{{ t('sidebar.servers') }}...</div>

    <div v-else class="recording-list-body">

      <!-- Split view: "all" tab when team joined -->
      <template v-if="showSplitView">
        <!-- Private recordings grouped by server -->
        <template v-for="(group, serverId) in privateGrouped" :key="serverId">
          <div class="recording-group-header">{{ group.serverName }} <span style="color:var(--tm-text-muted)">({{ group.recordings.length }})</span></div>
          <div
            v-for="rec in group.recordings"
            :key="rec.id"
            class="recording-item group"
            @mouseenter="hoveredId = rec.id"
            @mouseleave="hoveredId = null"
          >
            <div class="recording-item-main">
              <span class="recording-item-time">{{ new Date(rec.startedAt).toLocaleString() }}</span>
              <span style="color: var(--tm-text-muted)">
                {{ formatDuration(Math.floor(rec.durationMs / 1000)) }}
                &middot; {{ formatFileSize(rec.fileSize) }}
              </span>
              <span v-if="rec.autoRecorded" class="recording-badge-auto">AUTO</span>
            </div>
            <div class="recording-item-actions">
              <!-- Team share toggle (hover, right side) -->
              <el-tooltip
                v-if="teamStore.isJoined && !rec.teamId"
                :content="rec.shared ? t('context.makePrivate') : t('context.shareWithTeam')"
                :show-after="0"
              >
                <button
                  class="rec-action-btn shrink-0"
                  :class="(hoveredId === rec.id || rec.shared) ? 'opacity-100' : 'opacity-0'"
                  :style="{ color: rec.shared ? 'var(--el-color-success)' : 'var(--tm-text-muted)' }"
                  @click.stop="toggleShare(rec)"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </button>
              </el-tooltip>
              <button class="rec-action-btn rec-action-play" :title="t('recording.startRecording')" @click="playRecording(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              </button>
              <button class="rec-action-btn rec-action-delete" :title="t('sftp.delete')" @click="handleDelete(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              </button>
            </div>
          </div>
        </template>

        <!-- Divider (only when both sections have content) -->
        <div
          v-if="hasPrivateRecordings && hasTeamRecordings"
          class="mx-2 my-1"
          style="border-top: 1px solid var(--tm-border)"
        />

        <!-- Team section header -->
        <div
          v-if="hasTeamRecordings"
          class="flex items-center gap-1.5 px-2 py-1"
          style="color: #60a5fa"
        >
          <svg class="w-3 h-3 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          <span class="text-[10px] font-medium">{{ t('sidebar.teamServers') }}</span>
        </div>

        <!-- Team recordings grouped by server -->
        <template v-for="(group, serverId) in teamGrouped" :key="'team-' + serverId">
          <div class="recording-group-header">{{ group.serverName }} <span style="color:var(--tm-text-muted)">({{ group.recordings.length }})</span></div>
          <div
            v-for="rec in group.recordings"
            :key="rec.id"
            class="recording-item"
            @mouseenter="hoveredId = rec.id"
            @mouseleave="hoveredId = null"
          >
            <div class="recording-item-main">
              <span class="recording-item-time">{{ new Date(rec.startedAt).toLocaleString() }}</span>
              <span style="color: var(--tm-text-muted)">
                {{ formatDuration(Math.floor(rec.durationMs / 1000)) }}
                &middot; {{ formatFileSize(rec.fileSize) }}
              </span>
              <span v-if="rec.autoRecorded" class="recording-badge-auto">AUTO</span>
            </div>
            <div class="recording-item-actions">
              <!-- Team-received: always-visible make-local button -->
              <el-tooltip
                v-if="rec.teamId"
                :content="t('team.receivedFrom', { name: rec.sharedBy || '?' })"
                :show-after="0"
              >
                <button
                  class="rec-action-btn"
                  style="color: var(--el-color-primary); opacity: 1"
                  @click.stop="makeLocal(rec)"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </button>
              </el-tooltip>
              <!-- Shared-by-me: make-private button -->
              <el-tooltip
                v-else-if="rec.shared"
                :content="t('context.makePrivate')"
                :show-after="0"
              >
                <button
                  class="rec-action-btn"
                  style="color: var(--el-color-success); opacity: 1"
                  @click.stop="toggleShare(rec)"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </button>
              </el-tooltip>
              <button class="rec-action-btn rec-action-play" :title="t('recording.startRecording')" @click="playRecording(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              </button>
              <button class="rec-action-btn rec-action-delete" :title="t('sftp.delete')" @click="handleDelete(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              </button>
            </div>
          </div>
        </template>

        <!-- Empty split view -->
        <div
          v-if="!hasPrivateRecordings && !hasTeamRecordings"
          class="recording-list-empty"
        >
          {{ t('recording.startRecording') }}...
        </div>
      </template>

      <!-- Single-section view (private tab, team tab, or no team) -->
      <template v-else-if="Object.keys(visibleGrouped).length > 0">
        <template v-for="(group, serverId) in visibleGrouped" :key="serverId">
          <div class="recording-group-header">{{ group.serverName }} <span style="color:var(--tm-text-muted)">({{ group.recordings.length }})</span></div>
          <div
            v-for="rec in group.recordings"
            :key="rec.id"
            class="recording-item"
            @mouseenter="hoveredId = rec.id"
            @mouseleave="hoveredId = null"
          >
            <div class="recording-item-main">
              <span class="recording-item-time">{{ new Date(rec.startedAt).toLocaleString() }}</span>
              <span style="color: var(--tm-text-muted)">
                {{ formatDuration(Math.floor(rec.durationMs / 1000)) }}
                &middot; {{ formatFileSize(rec.fileSize) }}
              </span>
              <span v-if="rec.autoRecorded" class="recording-badge-auto">AUTO</span>
            </div>
            <div class="recording-item-actions">
              <el-tooltip
                v-if="teamStore.isJoined && !rec.teamId"
                :content="rec.shared ? t('context.makePrivate') : t('context.shareWithTeam')"
                :show-after="0"
              >
                <button
                  class="rec-action-btn shrink-0"
                  :class="(hoveredId === rec.id || rec.shared) ? 'opacity-100' : 'opacity-0'"
                  :style="{ color: rec.shared ? 'var(--el-color-success)' : 'var(--tm-text-muted)' }"
                  @click.stop="toggleShare(rec)"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </button>
              </el-tooltip>
              <el-tooltip
                v-else-if="rec.teamId"
                :content="t('team.receivedFrom', { name: rec.sharedBy || '?' })"
                :show-after="0"
              >
                <button
                  class="rec-action-btn"
                  style="color: var(--el-color-primary); opacity: 1"
                  @click.stop="makeLocal(rec)"
                >
                  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
                  </svg>
                </button>
              </el-tooltip>
              <button class="rec-action-btn rec-action-play" :title="t('recording.startRecording')" @click="playRecording(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
              </button>
              <button class="rec-action-btn rec-action-delete" :title="t('sftp.delete')" @click="handleDelete(rec)">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
              </button>
            </div>
          </div>
        </template>
      </template>

      <!-- Empty state -->
      <div
        v-else
        class="recording-list-empty"
      >
        {{ t('recording.startRecording') }}...
      </div>

    </div>
  </div>
</template>

<style scoped>
.recording-list {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--tm-bg-base);
  color: var(--tm-text-primary);
}
.recording-list-body {
  flex: 1;
  overflow-y: auto;
  padding: 4px 0;
}
.recording-list-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: 1;
  font-size: 0.75rem;
  color: var(--tm-text-muted);
  padding: 32px 12px;
}
.recording-group-header {
  padding: 4px 12px;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--tm-text-secondary);
}
.recording-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 4px 4px 20px;
  font-size: 0.75rem;
  transition: background 0.1s;
}
.recording-item:hover {
  background: var(--tm-bg-hover);
}
.recording-item-main {
  display: flex;
  align-items: center;
  gap: 8px;
  white-space: nowrap;
  overflow: hidden;
}
.recording-item-time {
  color: var(--tm-text-secondary);
  white-space: nowrap;
}
.recording-item-actions {
  display: flex;
  gap: 0;
  opacity: 0;
  transition: opacity 0.15s;
  margin-left: auto;
  flex-shrink: 0;
}
.recording-item:hover .recording-item-actions {
  opacity: 1;
}
.rec-action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border: none;
  background: transparent;
  border-radius: 3px;
  cursor: pointer;
  transition: all 0.15s;
}
.rec-action-play {
  color: var(--tm-text-muted);
}
.rec-action-play:hover {
  color: var(--el-color-primary, #409eff);
}
.rec-action-delete {
  color: var(--tm-text-muted);
}
.rec-action-delete:hover {
  color: #f56c6c;
}
.recording-badge-auto {
  font-size: 9px;
  font-weight: 600;
  color: #e6a23c;
  background: rgba(230, 162, 60, 0.1);
  padding: 0 4px;
  border-radius: 2px;
}
</style>
