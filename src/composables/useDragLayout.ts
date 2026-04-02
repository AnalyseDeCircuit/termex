import { ref, onUnmounted } from "vue";
import { useSettingsStore } from "@/stores/settingsStore";

export type DropTarget = "right" | "bottom" | "tabs" | null;

/**
 * Composable for drag-based layout switching.
 * Unified drag handler: works in all modes (tabs / right / bottom).
 * Drop zones:
 *   - Right 1/3 → "right" split
 *   - Bottom 1/3 → "bottom" split
 *   - Center area → "tabs" mode (restore)
 */
export function useDragLayout() {
  const settingsStore = useSettingsStore();
  const dragging = ref(false);
  const dropTarget = ref<DropTarget>(null);

  let startX = 0;
  let startY = 0;
  let workspaceEl: HTMLElement | null = null;
  let currentLayout: string = "tabs";

  function startDrag(e: MouseEvent, workspace: HTMLElement) {
    startX = e.clientX;
    startY = e.clientY;
    workspaceEl = workspace;
    currentLayout = settingsStore.sftpLayout ?? "tabs";

    window.addEventListener("mousemove", onMove);
    window.addEventListener("mouseup", onEnd);
  }

  function onMove(e: MouseEvent) {
    const dx = e.clientX - startX;
    const dy = e.clientY - startY;

    // Activate drag after 5px threshold
    if (!dragging.value && Math.abs(dx) + Math.abs(dy) > 5) {
      dragging.value = true;
    }

    if (!dragging.value || !workspaceEl) return;

    const rect = workspaceEl.getBoundingClientRect();
    const relX = e.clientX - rect.left;
    const relY = e.clientY - rect.top;

    // Determine drop target based on mouse position
    if (relX > rect.width * 0.67) {
      dropTarget.value = "right";
    } else if (relY > rect.height * 0.67) {
      dropTarget.value = "bottom";
    } else {
      // Center area = restore to tabs (only relevant in split modes)
      dropTarget.value = currentLayout !== "tabs" ? "tabs" : null;
    }

    // Don't show drop target for the current mode
    if (dropTarget.value === currentLayout) {
      dropTarget.value = null;
    }
  }

  function onEnd() {
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup", onEnd);

    if (dragging.value && dropTarget.value) {
      settingsStore.sftpLayout = dropTarget.value as "tabs" | "right" | "bottom";
    }

    dragging.value = false;
    dropTarget.value = null;
    workspaceEl = null;
  }

  onUnmounted(() => {
    window.removeEventListener("mousemove", onMove);
    window.removeEventListener("mouseup", onEnd);
  });

  return {
    dragging,
    dropTarget,
    startDrag,
  };
}
