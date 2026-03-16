import { GhostTileAppRecord } from "./ghosttile-types";
import { runGhosttile } from "./ghosttile-runner";

export async function loadManagedGhostTileApps(): Promise<GhostTileAppRecord[]> {
  const output = await runGhosttile(["status", "--json"]);
  return parseRecords(output).sort(byName);
}

function parseRecords(output: string): GhostTileAppRecord[] {
  if (!output.trim()) {
    return [];
  }

  return JSON.parse(output) as GhostTileAppRecord[];
}

function byName(a: GhostTileAppRecord, b: GhostTileAppRecord): number {
  return a.name.localeCompare(b.name);
}
