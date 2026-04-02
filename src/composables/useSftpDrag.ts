import { ref, computed, inject } from "vue";
import { useI18n } from "vue-i18n";
import { ElMessage } from "element-plus";
import { tauriInvoke } from "@/utils/tauri";
import { useSftpStore } from "@/stores/sftpStore";
import { tabSftpKey, type TabSftpContext } from "@/composables/useTabSftp";
import type { FileEntry } from "@/types/sftp";

/** Drag data payload shared between panes. */
export interface SftpDragData {
  side: "left" | "right";
  mode: "local" | "remote";
  sessionId: string | null;
  name: string;
  fullPath: string;
  isDir: boolean;
}

/**
 * Global drag state shared between pane instances.
 * Uses mouse events instead of HTML5 drag-drop (Tauri WKWebView
 * intercepts native drag events, making HTML5 drag-drop unreliable).
 */
const activeDrag = ref<SftpDragData | null>(null);
const isDragging = ref(false);
const dragGhostPos = ref({ x: 0, y: 0 });

/** Start threshold — only activate drag after moving 5px (avoids accidental drags). */
let mouseDownPos: { x: number; y: number } | null = null;
let pendingDragData: { entry: FileEntry; fullPath: string; side: "left" | "right"; mode: "local" | "remote"; sessionId: string | null } | null = null;

function onGlobalMouseMove(e: MouseEvent) {
  if (pendingDragData && mouseDownPos) {
    const dx = e.clientX - mouseDownPos.x;
    const dy = e.clientY - mouseDownPos.y;
    if (Math.abs(dx) + Math.abs(dy) > 5) {
      // Activate drag
      activeDrag.value = {
        side: pendingDragData.side,
        mode: pendingDragData.mode,
        sessionId: pendingDragData.sessionId,
        name: pendingDragData.entry.name,
        fullPath: pendingDragData.fullPath,
        isDir: pendingDragData.entry.isDir,
      };
      isDragging.value = true;
      pendingDragData = null;
    }
  }
  if (isDragging.value) {
    dragGhostPos.value = { x: e.clientX, y: e.clientY };
  }
}

function onGlobalMouseUp() {
  if (isDragging.value) {
    // Drop will be handled by the pane under the cursor via its mouseup handler
    // Clean up after a tick to let the drop handler read activeDrag
    setTimeout(() => {
      activeDrag.value = null;
      isDragging.value = false;
    }, 50);
  }
  pendingDragData = null;
  mouseDownPos = null;
}

// Register global listeners once
let globalListenersRegistered = false;
function ensureGlobalListeners() {
  if (globalListenersRegistered) return;
  globalListenersRegistered = true;
  window.addEventListener("mousemove", onGlobalMouseMove);
  window.addEventListener("mouseup", onGlobalMouseUp);
}

/**
 * Composable for SFTP cross-pane drag-and-drop using mouse events.
 */
export function useSftpDrag(side: "left" | "right") {
  const { t } = useI18n();
  const sftpStore = useSftpStore();
  const tabCtx = inject<TabSftpContext | null>(tabSftpKey, null);
  const ctx = tabCtx ?? sftpStore;

  const pane = computed(() => ctx.getPane(side));
  const isDropTarget = computed(() =>
    activeDrag.value !== null && activeDrag.value.side !== side && isDragging.value,
  );

  ensureGlobalListeners();

  /** Called on mousedown on a file entry — prepares for potential drag. */
  function handleMouseDown(e: MouseEvent, entry: FileEntry, fullPath: string) {
    if (e.button !== 0) return; // Left button only
    e.preventDefault(); // Prevent text selection during drag
    mouseDownPos = { x: e.clientX, y: e.clientY };
    pendingDragData = {
      entry,
      fullPath,
      side,
      mode: pane.value.mode,
      sessionId: pane.value.sessionId,
    };
  }

  /** Called on mouseup on a pane — handles drop if drag is active from the other pane. */
  async function handlePaneDrop() {
    const src = activeDrag.value;
    if (!src || src.side === side || !isDragging.value) return;

    if (src.isDir) {
      ElMessage.info(t("sftp.dirTransferTodo"));
      return;
    }

    const dst = pane.value;
    const dstBasePath = dst.currentPath === "/" ? "" : dst.currentPath;
    const dstFullPath = dst.mode === "local"
      ? `${dstBasePath}/${src.name}`
      : `${dstBasePath}/${src.name}`.replace(/\/+/g, "/");

    try {
      if (src.mode === "local" && dst.mode === "remote" && dst.sessionId) {
        await ctx.uploadFile(dst.sessionId, src.fullPath, dstFullPath);
        ElMessage.success(t("sftp.uploadStarted"));
      } else if (src.mode === "remote" && dst.mode === "local" && src.sessionId) {
        await ctx.downloadFile(src.sessionId, src.fullPath, dstFullPath);
        ElMessage.success(t("sftp.downloadStarted"));
      } else if (
        src.mode === "remote" && dst.mode === "remote" &&
        src.sessionId && dst.sessionId
      ) {
        if (src.sessionId === dst.sessionId) {
          await tauriInvoke("sftp_rename", {
            sessionId: dst.sessionId,
            oldPath: src.fullPath,
            newPath: dstFullPath,
          });
        } else {
          const srcName = ctx.getPane(src.side).serverName ?? src.sessionId;
          const dstName = dst.serverName ?? dst.sessionId;
          await ctx.serverToServerTransfer(
            src.sessionId, src.fullPath,
            dst.sessionId!, dstFullPath,
            srcName, dstName!,
          );
          ElMessage.success(t("sftp.serverTransfer"));
        }
      }
      // Pane refresh happens automatically when transfer completes
      // (via listenTransfer in sftpStore)
    } catch (err) {
      ElMessage.error(String(err));
    }
  }

  return {
    // State (for template rendering)
    activeDrag,
    isDragging,
    dragGhostPos,
    isDropTarget,
    // Handlers
    handleMouseDown,
    handlePaneDrop,
  };
}
