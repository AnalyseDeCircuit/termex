import { useTeamStore } from "@/stores/teamStore";
import type { Capability } from "@/types/team";

export function useTeamPermission() {
  const teamStore = useTeamStore();

  function can(capability: Capability, _groupId?: string): boolean {
    if (!teamStore.isJoined) return true;
    return teamStore.myCapabilities.includes(capability);
  }

  return { can };
}
