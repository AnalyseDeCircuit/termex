/** Supported network proxy types. */
export type ProxyType = "socks5" | "socks4" | "http" | "tor" | "command";

/** A network proxy configuration (read from backend). */
export interface Proxy {
  id: string;
  name: string;
  proxyType: ProxyType;
  host: string;
  port: number;
  username?: string;
  tlsEnabled: boolean;
  tlsVerify: boolean;
  caCertPath?: string;
  clientCertPath?: string;
  clientKeyPath?: string;
  /** ProxyCommand string (only for `command` type proxies). */
  command?: string;
  createdAt: string;
  updatedAt: string;
  /** Whether this proxy is shared with the team. */
  shared?: boolean;
  /** Team identifier (set when received from team sync). */
  teamId?: string;
  /** Username of the team member who shared this proxy. */
  sharedBy?: string;
}

/** Input for creating or updating a proxy. */
export interface ProxyInput {
  name: string;
  proxyType: ProxyType;
  host: string;
  port: number;
  username?: string;
  password?: string;
  tlsEnabled?: boolean;
  tlsVerify?: boolean;
  caCertPath?: string;
  clientCertPath?: string;
  clientKeyPath?: string;
  command?: string;
}
