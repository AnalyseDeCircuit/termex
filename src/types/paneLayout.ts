/** A node in the pane binary tree — either a leaf (terminal) or a split (container). */
export type PaneNode = PaneLeaf | PaneSplit;

/** Leaf node: contains a single terminal pane. */
export interface PaneLeaf {
  type: "leaf";
  /** Unique pane identifier. */
  id: string;
  /** SSH session ID for this pane. */
  sessionId: string;
  /** Server ID this pane connects to (for reconnect / clone). */
  serverId: string;
  /** Display title (server name or custom label). */
  title: string;
}

/** Split node: contains two children with a divider. */
export interface PaneSplit {
  type: "split";
  /** Unique split node identifier. */
  id: string;
  /** Split direction. */
  direction: "horizontal" | "vertical";
  /** Divider position as ratio (0.0 - 1.0). Default 0.5. */
  ratio: number;
  /** Exactly two children: [first, second].
   *  horizontal: first=top, second=bottom.
   *  vertical: first=left, second=right. */
  children: [PaneNode, PaneNode];
}

/** Broadcast mode state for a tab. */
export interface BroadcastState {
  /** Whether broadcast mode is active. */
  enabled: boolean;
  /** Pane IDs that receive broadcast input.
   *  When empty + enabled, ALL panes receive input. */
  includedPaneIds: Set<string>;
}

/** Minimum pane dimensions (in CSS pixels). */
export const MIN_PANE_WIDTH = 200;
export const MIN_PANE_HEIGHT = 120;

/** Minimum ratio to prevent panes from collapsing. */
export const MIN_SPLIT_RATIO = 0.15;
export const MAX_SPLIT_RATIO = 0.85;

/** Maximum split depth. Prevents infinitely small panes. */
export const MAX_SPLIT_DEPTH = 4;
