<script setup lang="ts">
import { ref, computed } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";
import type { ConflictItem, ConflictStrategy, ConflictResolution } from "@/types/team";

const props = defineProps<{
  modelValue: boolean;
  conflicts: ConflictItem[];
}>();

const emit = defineEmits<{
  (e: "update:modelValue", v: boolean): void;
  (e: "resolved"): void;
}>();

const { t } = useI18n();
const resolving = ref(false);

const strategies = ref<Map<string, ConflictStrategy>>(new Map());

function setStrategy(id: string, strategy: ConflictStrategy) {
  strategies.value.set(id, strategy);
}

function setAll(strategy: ConflictStrategy) {
  for (const c of props.conflicts) {
    strategies.value.set(c.entityId, strategy);
  }
}

const resolvedCount = computed(() => strategies.value.size);

async function apply() {
  resolving.value = true;
  try {
    // Items without an explicit strategy are treated as Skip
    const resolutions: ConflictResolution[] = props.conflicts
      .map((c) => ({
        entityType: c.entityType,
        entityId: c.entityId,
        strategy: strategies.value.get(c.entityId) ?? ("Skip" as const),
      }));

    await tauriInvoke("team_resolve_conflicts", { resolutions });
    ElMessage.success(t("teamV2.conflictResolved", { count: resolutions.length }));
    emit("resolved");
    emit("update:modelValue", false);
  } catch (err) {
    ElMessage.error(String(err));
  } finally {
    resolving.value = false;
  }
}

function close() {
  emit("update:modelValue", false);
}
</script>

<template>
  <el-dialog
    :model-value="modelValue"
    :title="t('teamV2.conflictTitle')"
    width="560px"
    @update:model-value="close"
  >
    <div class="flex flex-col gap-4">
      <p class="text-xs" style="color: var(--tm-text-secondary)">
        {{ t("teamV2.conflictDesc") }}
      </p>

      <!-- Conflict items -->
      <div
        v-for="conflict in conflicts"
        :key="conflict.entityId"
        class="rounded p-3 space-y-2"
        style="border: 1px solid var(--tm-border)"
      >
        <div class="flex items-center gap-2 text-xs font-medium" style="color: var(--tm-text-primary)">
          <span>{{ conflict.entityName }}</span>
          <span class="text-[10px] px-1 rounded" style="background: var(--tm-bg-hover); color: var(--tm-text-muted)">
            {{ conflict.entityType }}
          </span>
        </div>

        <!-- Field comparison table -->
        <div class="overflow-hidden rounded" style="border: 1px solid var(--tm-border)">
          <table class="w-full text-[11px]">
            <thead>
              <tr style="background: var(--tm-bg-secondary)">
                <th class="px-2 py-1 text-left font-normal" style="color: var(--tm-text-muted)">Field</th>
                <th class="px-2 py-1 text-left font-normal" style="color: var(--tm-text-muted)">{{ t("teamV2.conflictLocalVersion") }}</th>
                <th class="px-2 py-1 text-left font-normal" style="color: var(--tm-text-muted)">{{ t("teamV2.conflictRemoteVersion", { user: conflict.remoteModifiedBy }) }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="field in conflict.conflictingFields"
                :key="field"
              >
                <td class="px-2 py-1 font-mono" style="color: var(--tm-text-muted)">{{ field }}</td>
                <td class="px-2 py-1" style="color: var(--tm-text-primary)">{{ conflict.localValue[field] ?? "-" }}</td>
                <td class="px-2 py-1" style="color: var(--tm-text-primary)">{{ conflict.remoteValue[field] ?? "-" }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Strategy selection -->
        <div class="flex gap-2">
          <button
            class="text-[11px] px-2 py-1 rounded transition-colors"
            :style="{
              background: strategies.get(conflict.entityId) === 'KeepLocal' ? 'var(--el-color-primary)' : 'var(--tm-bg-secondary)',
              color: strategies.get(conflict.entityId) === 'KeepLocal' ? 'white' : 'var(--tm-text-primary)',
            }"
            @click="setStrategy(conflict.entityId, 'KeepLocal')"
          >
            {{ t("teamV2.conflictKeepLocal") }}
          </button>
          <button
            class="text-[11px] px-2 py-1 rounded transition-colors"
            :style="{
              background: strategies.get(conflict.entityId) === 'UseRemote' ? 'var(--el-color-primary)' : 'var(--tm-bg-secondary)',
              color: strategies.get(conflict.entityId) === 'UseRemote' ? 'white' : 'var(--tm-text-primary)',
            }"
            @click="setStrategy(conflict.entityId, 'UseRemote')"
          >
            {{ t("teamV2.conflictUseRemote") }}
          </button>
          <button
            class="text-[11px] px-2 py-1 rounded transition-colors"
            :style="{
              background: strategies.get(conflict.entityId) === 'Skip' ? 'var(--el-color-warning)' : 'var(--tm-bg-secondary)',
              color: strategies.get(conflict.entityId) === 'Skip' ? 'white' : 'var(--tm-text-muted)',
            }"
            @click="setStrategy(conflict.entityId, 'Skip')"
          >
            {{ t("teamV2.conflictSkip") }}
          </button>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex items-center gap-2">
        <button
          class="text-[11px] px-2 py-1 rounded"
          style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
          @click="setAll('KeepLocal')"
        >
          {{ t("teamV2.conflictAllLocal") }}
        </button>
        <button
          class="text-[11px] px-2 py-1 rounded"
          style="background: var(--tm-bg-secondary); color: var(--tm-text-primary)"
          @click="setAll('UseRemote')"
        >
          {{ t("teamV2.conflictAllRemote") }}
        </button>
        <div class="flex-1" />
        <el-button size="small" @click="close">{{ t("snippet.cancel") }}</el-button>
        <el-button
          size="small"
          type="primary"
          :loading="resolving"
          @click="apply"
        >
          {{ t("teamV2.conflictApply") }} ({{ resolvedCount }}/{{ conflicts.length }})
        </el-button>
      </div>
    </template>
  </el-dialog>
</template>
