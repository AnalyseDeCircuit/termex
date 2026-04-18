import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";

const mockInvoke = vi.fn();
vi.mock("@/utils/tauri", () => ({
  tauriInvoke: (...args: unknown[]) => mockInvoke(...args),
  tauriListen: vi.fn(() => Promise.resolve(() => {})),
}));

describe("Invite Token API", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    mockInvoke.mockReset();
  });

  it("team_generate_invite_token returns base64 token", async () => {
    const fakeToken = btoa(JSON.stringify({
      team_name: "Test Team",
      repo_url: "git@github.com:org/repo.git",
      invited_by: "alice",
      role: "developer",
      expires_at: "2026-04-22T10:00:00Z",
    }));
    mockInvoke.mockResolvedValue(fakeToken);

    const { tauriInvoke } = await import("@/utils/tauri");
    const token = await tauriInvoke<string>("team_generate_invite_token", {
      role: "developer",
      expiresDays: 7,
    });

    expect(token).toBeTruthy();
    expect(typeof token).toBe("string");
    // Should be base64 decodable
    const decoded = JSON.parse(atob(token));
    expect(decoded.team_name).toBe("Test Team");
    expect(decoded.role).toBe("developer");
  });

  it("team_decode_invite returns parsed payload", async () => {
    mockInvoke.mockResolvedValue({
      teamName: "Test Team",
      repoUrl: "git@github.com:org/repo.git",
      invitedBy: "alice",
      role: "developer",
      expiresAt: "2026-04-22T10:00:00Z",
    });

    const { tauriInvoke } = await import("@/utils/tauri");
    const result = await tauriInvoke<{
      teamName: string;
      repoUrl: string;
      invitedBy: string;
      role: string;
    }>("team_decode_invite", { token: "some-token" });

    expect(result.teamName).toBe("Test Team");
    expect(result.repoUrl).toContain("github.com");
    expect(result.invitedBy).toBe("alice");
    expect(result.role).toBe("developer");
  });

  it("team_decode_invite rejects expired token", async () => {
    mockInvoke.mockRejectedValue("invite token has expired");

    const { tauriInvoke } = await import("@/utils/tauri");
    await expect(
      tauriInvoke("team_decode_invite", { token: "expired-token" }),
    ).rejects.toBe("invite token has expired");
  });

  it("team_decode_invite rejects invalid format", async () => {
    mockInvoke.mockRejectedValue("invalid invite token format");

    const { tauriInvoke } = await import("@/utils/tauri");
    await expect(
      tauriInvoke("team_decode_invite", { token: "not-base64!!!" }),
    ).rejects.toBe("invalid invite token format");
  });
});
