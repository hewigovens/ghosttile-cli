import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { ghosttileBinaryCandidates } from "./ghosttile-path";

const execFileAsync = promisify(execFile);

export async function runGhosttile(args: string[]): Promise<string> {
  let lastError: unknown;
  const attempted: string[] = [];

  for (const candidate of new Set(ghosttileBinaryCandidates())) {
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
