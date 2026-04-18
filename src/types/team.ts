/** Fine-grained capability for permission checks. */
export type Capability =
  | "ServerConnect"
  | "ServerCreate"
  | "ServerEdit"
  | "ServerDelete"
  | "ServerViewCredentials"
  | "SnippetCreate"
  | "SnippetEdit"
  | "SnippetDelete"
  | "SnippetExecute"
  | "TeamInvite"
  | "TeamRemove"
  | "TeamRoleAssign"
  | "TeamSettingsEdit"
  | "SyncPush"
  | "SyncPull"
  | "AuditView"
  | "AuditExport";

/** Role definition with capability set. */
export interface TeamRole {
  displayName: string;
  capabilities: Capability[];
}

/** Team status returned by team_get_status. */
export interface TeamStatus {
  joined: boolean;
  name: string | null;
  role: string | null;
  memberCount: number;
  lastSync: string | null;
  hasPendingChanges: boolean;
  repoUrl: string | null;
  /** True when joined but team key could not be restored from keychain. */
  needsPassphrase: boolean;
}

/** Team member entry from team.json. */
export interface TeamMember {
  username: string;
  role: string;
  joinedAt: string;
  deviceId: string;
}

/** A detected conflict between local and remote. */
export interface ConflictItem {
  entityType: string;
  entityId: string;
  entityName: string;
  localValue: Record<string, unknown>;
  remoteValue: Record<string, unknown>;
  conflictingFields: string[];
  localModifiedBy: string;
  remoteModifiedBy: string;
  localModifiedAt: string;
  remoteModifiedAt: string;
}

/** Strategy for resolving a conflict. */
export type ConflictStrategy = "KeepLocal" | "UseRemote" | "Skip";

/** A single conflict resolution. */
export interface ConflictResolution {
  entityType: string;
  entityId: string;
  strategy: ConflictStrategy;
}

/** Result of a team sync operation. */
export interface TeamSyncResult {
  imported: number;
  exported: number;
  conflicts: ConflictItem[];
  deletedRemote: number;
}

/** Git authentication configuration. */
export interface GitAuthConfig {
  authType: "ssh_key" | "https_token" | "https_userpass";
  sshKeyPath?: string;
  sshPassphrase?: string;
  token?: string;
  username?: string;
  password?: string;
}

/** Returned by team_create / team_join. */
export interface TeamInfo {
  name: string;
  repoUrl: string;
  role: string;
  memberCount: number;
  createdAt: string;
}
