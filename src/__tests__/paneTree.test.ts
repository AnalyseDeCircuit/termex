import { describe, it, expect } from "vitest";
import {
  createLeaf,
  splitPane,
  closePane,
  updateRatio,
  collectLeafIds,
  findLeaf,
  countLeaves,
  findAdjacentLeaf,
  getTreeDepth,
  findPathToLeaf,
  findNearestLeaf,
  findPaneInDirection,
} from "@/utils/paneTree";
import type { PaneNode, PaneSplit } from "@/types/paneLayout";
import { MIN_SPLIT_RATIO, MAX_SPLIT_RATIO } from "@/types/paneLayout";

describe("paneTree", () => {
  // ── createLeaf ──
  it("createLeaf returns valid leaf", () => {
    const leaf = createLeaf("sess-1", "srv-1", "web-prod");
    expect(leaf.type).toBe("leaf");
    expect(leaf.id).toBeTruthy();
    expect(leaf.sessionId).toBe("sess-1");
    expect(leaf.serverId).toBe("srv-1");
    expect(leaf.title).toBe("web-prod");
  });

  // ── splitPane ──
  it("splitPane creates split with two children", () => {
    const leaf = createLeaf("s1", "srv", "title");
    const newLeaf = createLeaf("s2", "srv", "title2");
    const result = splitPane(leaf, leaf.id, "vertical", newLeaf);

    expect(result.type).toBe("split");
    if (result.type === "split") {
      expect(result.direction).toBe("vertical");
      expect(result.ratio).toBe(0.5);
      expect(result.children).toHaveLength(2);
    }
  });

  it("splitPane preserves existing leaf as first child", () => {
    const leaf = createLeaf("s1", "srv", "title");
    const newLeaf = createLeaf("s2", "srv", "title2");
    const result = splitPane(leaf, leaf.id, "horizontal", newLeaf);

    if (result.type === "split") {
      expect(result.children[0]).toEqual(leaf);
      expect(result.children[1]).toEqual(newLeaf);
    }
  });

  // ── closePane ──
  it("closePane removes leaf and collapses parent", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const split = splitPane(a, a.id, "vertical", b);

    const result = closePane(split, b.id);
    expect(result).toEqual(a);
  });

  it("closePane on root returns null", () => {
    const leaf = createLeaf("s1", "srv", "title");
    const result = closePane(leaf, leaf.id);
    expect(result).toBeNull();
  });

  it("closePane deeply nested", () => {
    // Build: ((A, B), C) — depth 2
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const c = createLeaf("s3", "srv", "C");

    let root = splitPane(a, a.id, "vertical", b);
    root = splitPane(root, root.id === a.id ? a.id : (root as PaneSplit).children[0].id, "horizontal", c);
    // Now we have a deeper tree. Close B:
    const result = closePane(root, b.id);
    expect(result).not.toBeNull();
    // B is gone, but tree still has A and C
    if (result) {
      const leaves = collectLeafIds(result);
      expect(leaves).toContain(a.id);
      expect(leaves).toContain(c.id);
      expect(leaves).not.toContain(b.id);
    }
  });

  // ── updateRatio ──
  it("updateRatio clamps to MIN/MAX", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const split = splitPane(a, a.id, "vertical", b);
    if (split.type !== "split") throw new Error("Expected split");

    const lowResult = updateRatio(split, split.id, 0.01);
    expect((lowResult as PaneSplit).ratio).toBe(MIN_SPLIT_RATIO);

    const highResult = updateRatio(split, split.id, 0.99);
    expect((highResult as PaneSplit).ratio).toBe(MAX_SPLIT_RATIO);

    const midResult = updateRatio(split, split.id, 0.6);
    expect((midResult as PaneSplit).ratio).toBe(0.6);
  });

  // ── collectLeafIds ──
  it("collectLeafIds returns DFS order", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const c = createLeaf("s3", "srv", "C");

    let root = splitPane(a, a.id, "vertical", b);
    // Split B into (B, C)
    root = splitPane(root, b.id, "horizontal", c);

    const ids = collectLeafIds(root);
    expect(ids).toEqual([a.id, b.id, c.id]);
  });

  // ── findLeaf ──
  it("findLeaf finds existing leaf", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);

    expect(findLeaf(root, a.id)).toEqual(a);
    expect(findLeaf(root, b.id)).toEqual(b);
    expect(findLeaf(root, "nonexistent")).toBeNull();
  });

  // ── countLeaves ──
  it("countLeaves counts correctly", () => {
    const a = createLeaf("s1", "srv", "A");
    expect(countLeaves(a)).toBe(1);

    const b = createLeaf("s2", "srv", "B");
    let root = splitPane(a, a.id, "vertical", b);
    expect(countLeaves(root)).toBe(2);

    const c = createLeaf("s3", "srv", "C");
    root = splitPane(root, b.id, "horizontal", c);
    expect(countLeaves(root)).toBe(3);

    const d = createLeaf("s4", "srv", "D");
    root = splitPane(root, a.id, "horizontal", d);
    expect(countLeaves(root)).toBe(4);
  });

  // ── findAdjacentLeaf ──
  it("findAdjacentLeaf wraps around", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const c = createLeaf("s3", "srv", "C");

    let root = splitPane(a, a.id, "vertical", b);
    root = splitPane(root, b.id, "horizontal", c);

    // Forward from C → wraps to A
    expect(findAdjacentLeaf(root, c.id, "next")).toBe(a.id);
    // Backward from A → wraps to C
    expect(findAdjacentLeaf(root, a.id, "prev")).toBe(c.id);
    // Forward from A → B
    expect(findAdjacentLeaf(root, a.id, "next")).toBe(b.id);
  });

  // ── getTreeDepth ──
  it("getTreeDepth single leaf", () => {
    const leaf = createLeaf("s1", "srv", "A");
    expect(getTreeDepth(leaf)).toBe(0);
  });

  it("getTreeDepth balanced 4 panes", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const c = createLeaf("s3", "srv", "C");
    const d = createLeaf("s4", "srv", "D");

    let root = splitPane(a, a.id, "vertical", b);
    root = splitPane(root, a.id, "horizontal", c);
    root = splitPane(root, b.id, "horizontal", d);

    expect(getTreeDepth(root)).toBe(2);
    expect(countLeaves(root)).toBe(4);
  });

  it("MAX_SPLIT_DEPTH prevents over-splitting", () => {
    let root: PaneNode = createLeaf("s1", "srv", "A");
    // Split 4 times to reach max depth
    for (let i = 0; i < 4; i++) {
      const ids = collectLeafIds(root);
      const lastId = ids[ids.length - 1];
      const newLeaf = createLeaf(`s${i + 2}`, "srv", `P${i + 2}`);
      root = splitPane(root, lastId, "vertical", newLeaf);
    }
    expect(getTreeDepth(root)).toBe(4);

    // 5th split should be blocked (returns root unchanged)
    const ids = collectLeafIds(root);
    const lastId = ids[ids.length - 1];
    const extraLeaf = createLeaf("blocked", "srv", "blocked");
    const result = splitPane(root, lastId, "vertical", extraLeaf);
    expect(result).toBe(root); // Unchanged reference
  });

  // ── findPathToLeaf ──
  it("findPathToLeaf returns correct path", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);
    if (root.type !== "split") throw new Error("Expected split");

    const pathA = findPathToLeaf(root, a.id);
    expect(pathA).not.toBeNull();
    expect(pathA!).toHaveLength(1);
    expect(pathA![0].childIndex).toBe(0);

    const pathB = findPathToLeaf(root, b.id);
    expect(pathB).not.toBeNull();
    expect(pathB!).toHaveLength(1);
    expect(pathB![0].childIndex).toBe(1);
  });

  it("findPathToLeaf returns null for missing leaf", () => {
    const a = createLeaf("s1", "srv", "A");
    expect(findPathToLeaf(a, "nonexistent")).toBeNull();
  });

  // ── findNearestLeaf ──
  it("findNearestLeaf picks first for down/right", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);

    // Entering from top-left → pick first leaf
    expect(findNearestLeaf(root, "down")).toBe(a.id);
    expect(findNearestLeaf(root, "right")).toBe(a.id);
  });

  it("findNearestLeaf picks last for up/left", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);

    // Entering from bottom-right → pick last leaf
    expect(findNearestLeaf(root, "up")).toBe(b.id);
    expect(findNearestLeaf(root, "left")).toBe(b.id);
  });

  // ── findPaneInDirection ──
  it("findPaneInDirection horizontal (up/down)", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "horizontal", b);

    expect(findPaneInDirection(root, a.id, "down")).toBe(b.id);
    expect(findPaneInDirection(root, b.id, "up")).toBe(a.id);
  });

  it("findPaneInDirection vertical (left/right)", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);

    expect(findPaneInDirection(root, a.id, "right")).toBe(b.id);
    expect(findPaneInDirection(root, b.id, "left")).toBe(a.id);
  });

  it("findPaneInDirection returns null at edge", () => {
    const a = createLeaf("s1", "srv", "A");
    const b = createLeaf("s2", "srv", "B");
    const root = splitPane(a, a.id, "vertical", b);

    // A is leftmost — no pane to the left
    expect(findPaneInDirection(root, a.id, "left")).toBeNull();
    // B is rightmost — no pane to the right
    expect(findPaneInDirection(root, b.id, "right")).toBeNull();
    // Horizontal direction on vertical split — no up/down neighbors
    expect(findPaneInDirection(root, a.id, "up")).toBeNull();
    expect(findPaneInDirection(root, b.id, "down")).toBeNull();
  });
});
