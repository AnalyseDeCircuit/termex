import { describe, it, expect, beforeEach, vi } from "vitest";
import { setActivePinia, createPinia } from "pinia";

vi.mock("@/utils/tauri", () => ({
  tauriInvoke: vi.fn(),
  tauriListen: vi.fn(() => Promise.resolve(() => {})),
}));

import { useSessionStore } from "@/stores/sessionStore";
import { useCloudStore } from "@/stores/cloudStore";

describe("Cloud Session Types", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("openKubeExec creates session with type kube-exec", () => {
    const store = useSessionStore();
    const sid = store.openKubeExec({
      context: "production",
      namespace: "default",
      pod: "nginx-abc123",
      container: "nginx",
    });

    expect(sid).toMatch(/^kube-/);
    const session = store.sessions.get(sid)!;
    expect(session).toBeDefined();
    expect(session.type).toBe("kube-exec");
    expect(session.status).toBe("connecting");
    expect(session.cloudMeta?.context).toBe("production");
    expect(session.cloudMeta?.namespace).toBe("default");
    expect(session.cloudMeta?.pod).toBe("nginx-abc123");
    expect(session.cloudMeta?.container).toBe("nginx");
  });

  it("openKubeExec creates tab with [k8s] suffix", () => {
    const store = useSessionStore();
    store.openKubeExec({
      context: "staging",
      namespace: "apps",
      pod: "api-xyz",
    });

    const tab = store.tabs[0];
    expect(tab).toBeDefined();
    expect(tab.title).toBe("api-xyz [k8s]");
    expect(tab.active).toBe(true);
  });

  it("openSsmSession creates session with type ssm", () => {
    const store = useSessionStore();
    const sid = store.openSsmSession({
      instanceId: "i-0abc123",
      instanceName: "web-server-1",
      profile: "prod",
      region: "us-east-1",
    });

    expect(sid).toMatch(/^ssm-/);
    const session = store.sessions.get(sid)!;
    expect(session.type).toBe("ssm");
    expect(session.cloudMeta?.instanceId).toBe("i-0abc123");
    expect(session.cloudMeta?.instanceName).toBe("web-server-1");
    expect(session.cloudMeta?.profile).toBe("prod");
    expect(session.cloudMeta?.region).toBe("us-east-1");
  });

  it("openSsmSession creates tab with [ssm] suffix", () => {
    const store = useSessionStore();
    store.openSsmSession({
      instanceId: "i-0def456",
      instanceName: "db-server",
    });

    expect(store.tabs[0].title).toBe("db-server [ssm]");
  });

  it("openKubeLogs creates session with type kube-logs and connected status", () => {
    const store = useSessionStore();
    const sid = store.openKubeLogs({
      context: "production",
      namespace: "default",
      pod: "nginx-abc",
      container: "nginx",
      tailLines: 200,
    });

    expect(sid).toMatch(/^kube-logs-/);
    const session = store.sessions.get(sid)!;
    expect(session.type).toBe("kube-logs");
    expect(session.status).toBe("connected");
    expect(session.cloudMeta?.pod).toBe("nginx-abc");
  });

  it("openKubeLogs creates tab with [logs] suffix", () => {
    const store = useSessionStore();
    store.openKubeLogs({
      context: "staging",
      namespace: "apps",
      pod: "worker-001",
    });

    expect(store.tabs[0].title).toBe("worker-001 [logs]");
  });

  it("cloud sessions initialize pane layout", () => {
    const store = useSessionStore();
    store.openKubeExec({
      context: "prod",
      namespace: "default",
      pod: "pod-1",
    });

    const tab = store.tabs[0];
    const layout = store.paneLayouts.get(tab.tabKey);
    expect(layout).toBeDefined();
    expect(layout!.type).toBe("leaf");
  });

  it("cloud meta fields are optional", () => {
    const store = useSessionStore();
    const sid = store.openSsmSession({
      instanceId: "i-abc",
      instanceName: "test",
    });
    const session = store.sessions.get(sid)!;
    expect(session.cloudMeta?.profile).toBeUndefined();
    expect(session.cloudMeta?.region).toBeUndefined();
  });
});

describe("Cloud Store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("initializes with empty state", () => {
    const store = useCloudStore();
    expect(store.tools).toEqual([]);
    expect(store.toolsLoaded).toBe(false);
    expect(store.kubeContexts).toEqual([]);
    expect(store.ssmProfiles).toEqual([]);
  });

  it("toggleNode toggles expansion state", () => {
    const store = useCloudStore();
    expect(store.isExpanded("test-key")).toBe(false);

    store.toggleNode("test-key");
    expect(store.isExpanded("test-key")).toBe(true);

    store.toggleNode("test-key");
    expect(store.isExpanded("test-key")).toBe(false);
  });

  it("getPods returns empty array for unknown key", () => {
    const store = useCloudStore();
    expect(store.getPods("unknown", "ns")).toEqual([]);
  });

  it("getSsmInstances returns empty array for unknown key", () => {
    const store = useCloudStore();
    expect(store.getSsmInstances("unknown")).toEqual([]);
  });

  it("kubeAvailable reflects tool detection", () => {
    const store = useCloudStore();
    store.tools = [
      { name: "kubectl", available: true, version: "v1.29.0", path: "/usr/local/bin/kubectl" },
      { name: "aws", available: false, version: null, path: null },
      { name: "session-manager-plugin", available: false, version: null, path: null },
    ];

    expect(store.kubeAvailable).toBe(true);
    expect(store.ssmAvailable).toBe(false);
  });

  it("ssmAvailable requires both aws and ssm-plugin", () => {
    const store = useCloudStore();
    store.tools = [
      { name: "kubectl", available: false, version: null, path: null },
      { name: "aws", available: true, version: "2.15.0", path: "/usr/local/bin/aws" },
      { name: "session-manager-plugin", available: true, version: "1.2.0", path: "/usr/local/bin/session-manager-plugin" },
    ];

    expect(store.kubeAvailable).toBe(false);
    expect(store.ssmAvailable).toBe(true);
  });
});

describe("Session Type Feature Matrix", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("all cloud session types have correct type field", () => {
    const store = useSessionStore();

    const kubeSid = store.openKubeExec({ context: "c", namespace: "n", pod: "p" });
    const ssmSid = store.openSsmSession({ instanceId: "i", instanceName: "n" });
    const logsSid = store.openKubeLogs({ context: "c", namespace: "n", pod: "p" });

    expect(store.sessions.get(kubeSid)!.type).toBe("kube-exec");
    expect(store.sessions.get(ssmSid)!.type).toBe("ssm");
    expect(store.sessions.get(logsSid)!.type).toBe("kube-logs");
  });

  it("kube-logs sessions start with connected status", () => {
    const store = useSessionStore();
    const sid = store.openKubeLogs({ context: "c", namespace: "n", pod: "p" });
    expect(store.sessions.get(sid)!.status).toBe("connected");
  });

  it("kube-exec and ssm sessions start with connecting status", () => {
    const store = useSessionStore();
    const kubeSid = store.openKubeExec({ context: "c", namespace: "n", pod: "p" });
    const ssmSid = store.openSsmSession({ instanceId: "i", instanceName: "n" });
    expect(store.sessions.get(kubeSid)!.status).toBe("connecting");
    expect(store.sessions.get(ssmSid)!.status).toBe("connecting");
  });
});
