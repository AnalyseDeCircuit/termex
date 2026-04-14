export interface ToolStatus {
  name: string;
  available: boolean;
  version: string | null;
  path: string | null;
}

export interface KubeContext {
  name: string;
  cluster: string;
  user: string;
  namespace?: string;
  isCurrent: boolean;
}

export interface PodInfo {
  name: string;
  namespace: string;
  status: string;
  ready: string;
  restarts: number;
  age: string;
  node: string;
  containers: ContainerInfo[];
}

export interface ContainerInfo {
  name: string;
  image: string;
  ready: boolean;
  restartCount: number;
  state: string;
}

export interface SsmInstance {
  instanceId: string;
  name: string;
  platform: string;
  ipAddress?: string;
  agentVersion: string;
  pingStatus: string;
}
