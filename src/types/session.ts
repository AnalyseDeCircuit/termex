export type SessionStatus = "connecting" | "authenticated" | "connected" | "disconnected" | "reconnecting" | "error";

export type SessionType = "ssh" | "local" | "kube-exec" | "ssm" | "kube-logs";

export interface CloudMeta {
  context?: string;
  namespace?: string;
  pod?: string;
  container?: string;
  instanceId?: string;
  instanceName?: string;
  profile?: string;
  region?: string;
}

export interface Session {
  id: string;
  serverId: string;
  serverName: string;
  status: SessionStatus;
  startedAt: string;
  type: SessionType;
  cloudMeta?: CloudMeta;
}

export interface Tab {
  /** Stable key for Vue v-for (does not change when sessionId is replaced). */
  tabKey: string;
  id: string;
  sessionId: string;
  title: string;
  active: boolean;
}
