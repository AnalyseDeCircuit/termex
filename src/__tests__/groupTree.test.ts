import { describe, it, expect } from "vitest";
import { buildGroupTree, countServers } from "@/utils/groupTree";
import type { Server, ServerGroup } from "@/types/server";

function group(id: string, parentId: string | null = null): ServerGroup {
  return {
    id,
    name: id,
    color: "#fff",
    icon: "",
    parentId,
    sortOrder: 0,
    createdAt: "",
    updatedAt: "",
  };
}

function server(id: string, groupId: string | null): Server {
  return { id, groupId } as unknown as Server;
}

describe("buildGroupTree", () => {
  it("renders a subgroup nested under its parent", () => {
    const tree = buildGroupTree(
      [group("root"), group("child", "root")],
      [server("s1", "root"), server("s2", "child")],
    );

    expect(tree).toHaveLength(1);
    expect(tree[0].id).toBe("root");
    expect(tree[0].servers.map((s) => s.id)).toEqual(["s1"]);
    expect(tree[0].children).toHaveLength(1);
    expect(tree[0].children[0].id).toBe("child");
    expect(tree[0].children[0].servers.map((s) => s.id)).toEqual(["s2"]);
  });

  // Issue #21: a parent holding no servers of its own was dropped, taking the
  // entire subtree with it.
  it("keeps a parent whose servers live only in subgroups", () => {
    const tree = buildGroupTree(
      [group("root"), group("child", "root")],
      [server("s1", "child")],
    );

    expect(tree).toHaveLength(1);
    expect(tree[0].servers).toEqual([]);
    expect(tree[0].children[0].servers.map((s) => s.id)).toEqual(["s1"]);
  });

  it("nests beyond two levels", () => {
    const tree = buildGroupTree(
      [group("a"), group("b", "a"), group("c", "b"), group("d", "c")],
      [server("s1", "d")],
    );

    expect(tree[0].children[0].children[0].id).toBe("c");
    expect(tree[0].children[0].children[0].children[0].id).toBe("d");
    expect(
      tree[0].children[0].children[0].children[0].servers.map((s) => s.id),
    ).toEqual(["s1"]);
  });

  it("drops groups with no servers anywhere in their subtree", () => {
    const tree = buildGroupTree(
      [group("empty"), group("emptyChild", "empty"), group("full")],
      [server("s1", "full")],
    );

    expect(tree.map((g) => g.id)).toEqual(["full"]);
  });

  it("applies the belongs predicate to split private and team servers", () => {
    const groups = [group("root")];
    const servers = [
      { id: "priv", groupId: "root", shared: false },
      { id: "team", groupId: "root", shared: true },
    ] as unknown as Server[];

    const priv = buildGroupTree(
      groups,
      servers,
      (s) => !(s as unknown as { shared: boolean }).shared,
    );
    const team = buildGroupTree(
      groups,
      servers,
      (s) => (s as unknown as { shared: boolean }).shared,
    );

    expect(priv[0].servers.map((s) => s.id)).toEqual(["priv"]);
    expect(team[0].servers.map((s) => s.id)).toEqual(["team"]);
  });

  it("promotes a group to root when its parent no longer exists", () => {
    const tree = buildGroupTree(
      [group("orphan", "deleted-group")],
      [server("s1", "orphan")],
    );

    expect(tree).toHaveLength(1);
    expect(tree[0].id).toBe("orphan");
    expect(tree[0].servers.map((s) => s.id)).toEqual(["s1"]);
  });

  it("terminates on a parentId cycle instead of recursing forever", () => {
    const a = group("a", "b");
    const b = group("b", "a");

    const tree = buildGroupTree([a, b], [server("s1", "a"), server("s2", "b")]);

    // Neither is a root, so the cycle contributes nothing — but it must return.
    expect(Array.isArray(tree)).toBe(true);
  });
});

describe("countServers", () => {
  it("sums a node and all descendants", () => {
    const tree = buildGroupTree(
      [group("a"), group("b", "a"), group("c", "b")],
      [
        server("s1", "a"),
        server("s2", "b"),
        server("s3", "c"),
        server("s4", "c"),
      ],
    );

    expect(countServers(tree[0])).toBe(4);
    expect(countServers(tree[0].children[0])).toBe(3);
  });
});
