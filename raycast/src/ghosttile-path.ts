import { getPreferenceValues } from "@raycast/api";

type Preferences = {
  ghosttilePath?: string;
};

export function ghosttileBinaryCandidates(): string[] {
  const preferences = getPreferenceValues<Preferences>();

  return [
    preferences.ghosttilePath?.trim(),
    "/usr/local/bin/ghosttile",
    "ghosttile",
  ].filter((value): value is string => Boolean(value && value.length > 0));
}
