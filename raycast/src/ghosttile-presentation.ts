import { Color, Icon, Image, List } from "@raycast/api";
import { GhostTileAppRecord } from "./ghosttile-types";

export function ghostTileIcon(): Image.ImageLike {
  return {
    source: "icon.png",
    fallback: Icon.EyeDisabled,
  };
}

export function appIcon(app: GhostTileAppRecord): Image.ImageLike {
  if (app.appPath.length > 0) {
    return {
      fileIcon: app.appPath,
      fallback: app.hiddenFromDock ? Icon.EyeDisabled : Icon.AppWindow,
    };
  }

  return app.hiddenFromDock ? Icon.EyeDisabled : Icon.AppWindow;
}

export function managedAccessory(app: GhostTileAppRecord): List.Item.Accessory {
  if (!app.running) {
    return {
      icon: { source: Icon.Circle, tintColor: Color.SecondaryText },
      text: "Not Running",
    };
  }

  if (app.hiddenFromDock) {
    return {
      icon: { source: Icon.EyeDisabled, tintColor: Color.Orange },
      text: "Hidden",
    };
  }

  return {
    icon: { source: Icon.AppWindow, tintColor: Color.Green },
    text: "Visible",
  };
}

export function summarizeOutput(output: string): string | undefined {
  const lines = output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  return lines.at(-1);
}
