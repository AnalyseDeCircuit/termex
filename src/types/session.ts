export type SessionStatus = "connecting" | "connected" | "disconnected" | "error";

export interface Session {
  id: string;
  serverId: string;
  serverName: string;
  status: SessionStatus;
  startedAt: string;
}

export interface Tab {
  /** Stable key for Vue v-for (does not change when sessionId is replaced). */
  tabKey: string;
  id: string;
  sessionId: string;
  title: string;
  active: boolean;
}
