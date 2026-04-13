import type { PaneNode, PaneLeaf, PaneSplit } from "@/types/paneLayout";
import { MIN_SPLIT_RATIO, MAX_SPLIT_RATIO, MAX_SPLIT_DEPTH } from "@/types/paneLayout";

let counter = 0;
function uid(): string {
  return `pane-${Date.now()}-${++counter}`;
}

/** Creates a new leaf pane. */
export function createLeaf(sessionId: string, serverId: string, title: string): PaneLeaf {
  return { type: "leaf", id: uid(), sessionId, serverId, title };
}

/** Splits a target pane into two, returning a new tree root.
 *  Returns the original root unchanged if target not found or max depth reached. */
export function splitPane(
  root: PaneNode,
  targetPaneId: string,
  direction: "horizontal" | "vertical",
  newLeaf: PaneLeaf,
): PaneNode {
  if (getTreeDepth(root) >= MAX_SPLIT_DEPTH) return root;
  return transformNode(root, targetPaneId, (leaf) => ({
    type: "split",
    id: uid(),
    direction,
    ratio: 0.5,
    children: [leaf, newLeaf],
  }));
}

/** Closes a pane and collapses its parent split. Returns null if root was removed. */
export function closePane(root: PaneNode, targetPaneId: string): PaneNode | null {
  if (root.type === "leaf") {
    return root.id === targetPaneId ? null : root;
  }

  const [first, second] = root.children;

  if (first.type === "leaf" && first.id === targetPaneId) return second;
  if (second.type === "leaf" && second.id === targetPaneId) return first;

  const newFirst = closePane(first, targetPaneId);
  const newSecond = closePane(second, targetPaneId);

  if (newFirst === null) return newSecond;
  if (newSecond === null) return newFirst;

  return { ...root, children: [newFirst, newSecond] };
}

/** Updates the split ratio for a specific split node. */
export function updateRatio(root: PaneNode, splitId: string, ratio: number): PaneNode {
  const clamped = Math.max(MIN_SPLIT_RATIO, Math.min(MAX_SPLIT_RATIO, ratio));
  return transformNode(root, splitId, (node) => {
    if (node.type === "split") {
      return { ...node, ratio: clamped };
    }
    return node;
  });
}

/** Collects all leaf pane IDs in DFS order. */
export function collectLeafIds(node: PaneNode): string[] {
  if (node.type === "leaf") return [node.id];
  return [...collectLeafIds(node.children[0]), ...collectLeafIds(node.children[1])];
}

/** Finds a leaf by ID. */
export function findLeaf(node: PaneNode, id: string): PaneLeaf | null {
  if (node.type === "leaf") return node.id === id ? node : null;
  return findLeaf(node.children[0], id) ?? findLeaf(node.children[1], id);
}

/** Counts total leaf panes. */
export function countLeaves(node: PaneNode): number {
  if (node.type === "leaf") return 1;
  return countLeaves(node.children[0]) + countLeaves(node.children[1]);
}

/** Finds the next/previous leaf in DFS order for focus navigation (wraps around). */
export function findAdjacentLeaf(
  root: PaneNode,
  currentId: string,
  direction: "next" | "prev",
): string | null {
  const ids = collectLeafIds(root);
  const idx = ids.indexOf(currentId);
  if (idx === -1) return null;

  if (direction === "next") {
    return ids[(idx + 1) % ids.length];
  } else {
    return ids[(idx - 1 + ids.length) % ids.length];
  }
}

/** Calculates the depth of a pane tree. */
export function getTreeDepth(node: PaneNode): number {
  if (node.type === "leaf") return 0;
  return 1 + Math.max(getTreeDepth(node.children[0]), getTreeDepth(node.children[1]));
}

// ── Directional navigation ──────────────────────────────────

/** Path entry: the split node and which child (0 or 1) was taken. */
interface PathEntry {
  node: PaneSplit;
  childIndex: 0 | 1;
}

/** Finds the path from root to a leaf node. Returns null if not found. */
export function findPathToLeaf(root: PaneNode, leafId: string): PathEntry[] | null {
  if (root.type === "leaf") {
    return root.id === leafId ? [] : null;
  }

  for (const childIndex of [0, 1] as const) {
    const child = root.children[childIndex];
    const subPath =
      child.type === "leaf" && child.id === leafId
        ? []
        : findPathToLeaf(child, leafId);

    if (subPath !== null) {
      return [{ node: root, childIndex }, ...subPath];
    }
  }

  return null;
}

/** Finds the nearest leaf when descending into a subtree from a given direction.
 *  "up"/"left" → entering from bottom/right, pick the LAST leaf (closest to edge).
 *  "down"/"right" → entering from top/left, pick the FIRST leaf. */
export function findNearestLeaf(
  node: PaneNode,
  enterDirection: "up" | "down" | "left" | "right",
): string | null {
  if (node.type === "leaf") return node.id;

  const pickLast = enterDirection === "up" || enterDirection === "left";
  const targetChild = pickLast ? node.children[1] : node.children[0];
  const fallbackChild = pickLast ? node.children[0] : node.children[1];

  return findNearestLeaf(targetChild, enterDirection) ?? findNearestLeaf(fallbackChild, enterDirection);
}

/** Finds the pane in a given spatial direction relative to the current pane. */
export function findPaneInDirection(
  root: PaneNode,
  currentId: string,
  direction: "up" | "down" | "left" | "right",
): string | null {
  const path = findPathToLeaf(root, currentId);
  if (!path) return null;

  const targetAxis: "horizontal" | "vertical" =
    direction === "up" || direction === "down" ? "horizontal" : "vertical";
  // Which child position the current node must be in for movement to be valid
  const fromChild: 0 | 1 = direction === "up" || direction === "left" ? 1 : 0;

  for (let i = path.length - 1; i >= 0; i--) {
    const { node, childIndex } = path[i];
    if (node.direction === targetAxis && childIndex === fromChild) {
      const otherChild = node.children[1 - fromChild];
      return findNearestLeaf(otherChild, direction);
    }
  }

  return null;
}

// ── Internal helpers ────────────────────────────────────────

/** Recursively transforms a node matching targetId. */
function transformNode(
  node: PaneNode,
  targetId: string,
  transform: (node: PaneNode) => PaneNode,
): PaneNode {
  if (node.type === "leaf" && node.id === targetId) {
    return transform(node);
  }
  if (node.type === "split") {
    if (node.id === targetId) return transform(node);
    return {
      ...node,
      children: [
        transformNode(node.children[0], targetId, transform),
        transformNode(node.children[1], targetId, transform),
      ],
    };
  }
  return node;
}
