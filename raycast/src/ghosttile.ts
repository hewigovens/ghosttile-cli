import { getPreferenceValues } from "@raycast/api";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

type Preferences = {
  ghosttilePath?: string;
};

export type GhostTileAppRecord = {
  bundleId: string;
  name: string;
  appPath: string;
  binaryPath: string;
  managed: boolean;
  running: boolean;
  hiddenFromDock: boolean;
  pid?: number;
};

export async function loadManagedGhostTileApps(): Promise<GhostTileAppRecord[]> {
  const output = await runGhosttile(["status", "--json"]);
  return parseRecords(output).sort(byName);
}

export async function runGhosttile(args: string[]): Promise<string> {
  const preferences = getPreferenceValues<Preferences>();
  const candidates = [
    preferences.ghosttilePath?.trim(),
    "/usr/local/bin/ghosttile",
    "/opt/homebrew/bin/ghosttile",
    "ghosttile",
  ].filter((value): value is string => Boolean(value && value.length > 0));

  let lastError: unknown;
  const attempted: string[] = [];

  for (const candidate of new Set(candidates)) {
    attempted.push(candidate);
    try {
      const result = await execFileAsync(candidate, args, {
        maxBuffer: 1024 * 1024,
      });
      return (result.stdout ?? "").trim();
    } catch (error) {
      lastError = error;
    }
  }

  throw new Error(formatCommandError(lastError, attempted));
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

function formatCommandError(error: unknown, attempted: string[]): string {
  if (error instanceof Error && error.message) {
    const attemptedText = attempted.length > 0 ? ` Tried: ${attempted.join(", ")}` : "";
    return `${error.message}${attemptedText}`;
  }

  if (attempted.length > 0) {
    return `Failed to run ghosttile. Tried: ${attempted.join(", ")}`;
  }

  return "Failed to run ghosttile.";
}
