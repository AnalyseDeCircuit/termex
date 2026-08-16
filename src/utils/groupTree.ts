import type { GroupNode, Server, ServerGroup } from "@/types/server";

/**
 * Build the nested sidebar group tree.
 *
 * Replaces the previous two-level construction, which collected root groups via
 * `!parentId` and one level of children, then dropped any group with no direct
 * servers. That had two consequences (issue #21):
 *   - subgroups were never rendered, because nothing consumed the `children`
 *     array the sidebar computed;
 *   - a parent whose servers all lived in subgroups was filtered away, hiding
 *     the entire subtree with it.
 *
 * Here a group survives when it holds servers *or* any descendant does, and the
 * recursion has no depth limit.
 *
 * @param belongs Predicate selecting which servers this tree may show — used to
 *                split the private and team sections of the sidebar.
 */
export function buildGroupTree(
  groups: ServerGroup[],
  servers: Server[],
  belongs: (s: Server) => boolean = () => true,
): GroupNode[] {
  const known = new Set(groups.map((g) => g.id));

  // A group whose parent no longer exists is treated as a root rather than
  // orphaned, so a dangling parentId can never make servers unreachable.
  const parentOf = (g: ServerGroup): string | null =>
    g.parentId && known.has(g.parentId) ? g.parentId : null;

  const byParent = new Map<string | null, ServerGroup[]>();
  for (const g of groups) {
    const key = parentOf(g);
    const siblings = byParent.get(key);
    if (siblings) siblings.push(g);
    else byParent.set(key, [g]);
  }

  // parentId cycles would otherwise recurse forever.
  const visited = new Set<string>();

  function build(parentId: string | null): GroupNode[] {
    const nodes: GroupNode[] = [];
    for (const g of byParent.get(parentId) ?? []) {
      if (visited.has(g.id)) continue;
      visited.add(g.id);

      const node: GroupNode = {
        ...g,
        children: build(g.id),
        servers: servers.filter((s) => s.groupId === g.id && belongs(s)),
      };

      if (node.servers.length > 0 || node.children.length > 0) {
        nodes.push(node);
      }
    }
    return nodes;
  }

  return build(null);
}

/** Total servers held by a node and every descendant, for the count badge. */
export function countServers(node: GroupNode): number {
  return (
    node.servers.length +
    node.children.reduce((total, child) => total + countServers(child), 0)
  );
}
