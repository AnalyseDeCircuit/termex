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

/** A saved reference to a cloud resource that can be shared with the team. */
export interface CloudFavorite {
  id: string;
  name: string;
  /** "kube" or "ssm" */
  resourceType: string;
  /** K8s context name or AWS profile name */
  contextOrProfile: string;
  namespace?: string;
  region?: string;
  shared: boolean;
  teamId?: string;
  sharedBy?: string;
  createdAt: string;
  updatedAt: string;
}

export interface CloudFavoriteInput {
  name: string;
  resourceType: string;
  contextOrProfile: string;
  namespace?: string;
  region?: string;
}
