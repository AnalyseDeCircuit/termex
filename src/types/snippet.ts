/** A saved command snippet. */
export interface Snippet {
  id: string;
  title: string;
  description?: string;
  command: string;
  tags: string[];
  folderId?: string;
  isFavorite: boolean;
  usageCount: number;
  lastUsedAt?: string;
  createdAt: string;
  updatedAt: string;
  /** Whether this snippet is shared with the team. */
  shared?: boolean;
  /** Team identifier (set when received from team sync). */
  teamId?: string;
  /** Username of the team member who shared this snippet. */
  sharedBy?: string;
}

/** Input for creating or updating a snippet. */
export interface SnippetInput {
  title: string;
  description?: string;
  command: string;
  tags: string[];
  folderId?: string;
  isFavorite: boolean;
}

/** A folder for organizing snippets. */
export interface SnippetFolder {
  id: string;
  name: string;
  parentId?: string;
  sortOrder: number;
  createdAt: string;
}

/** Input for creating or updating a snippet folder. */
export interface SnippetFolderInput {
  name: string;
  parentId?: string;
  sortOrder: number;
}
