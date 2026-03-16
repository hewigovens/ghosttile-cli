import { Action, ActionPanel, Color, Icon, Image, List, Toast, showToast } from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import { GhostTileAppRecord, loadManagedGhostTileApps, runGhosttile } from "./ghosttile";

export default function Command() {
  const [apps, setApps] = useState<GhostTileAppRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string>();

  const refresh = useCallback(async () => {
    setIsLoading(true);
    try {
      const nextApps = await loadManagedGhostTileApps();
      setApps(nextApps);
      setError(undefined);
    } catch (refreshError) {
      setError(refreshError instanceof Error ? refreshError.message : "Failed to load managed GhostTile apps.");
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  async function runAction(title: string, args: string[]): Promise<void> {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title,
    });

    try {
      const output = await runGhosttile(args);
      toast.style = Toast.Style.Success;
      toast.title = title;
      toast.message = summarizeOutput(output);
      await refresh();
    } catch (actionError) {
      toast.style = Toast.Style.Failure;
      toast.title = title;
      toast.message = actionError instanceof Error ? actionError.message : "GhostTile command failed.";
    }
  }

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search managed apps">
      {error ? (
        <List.Item
          id="ghosttile-error"
          title="GhostTile command failed"
          subtitle={error}
          icon={ghostTileIcon()}
          actions={
            <ActionPanel>
              <Action title="Retry" onAction={() => void refresh()} />
            </ActionPanel>
          }
        />
      ) : null}

      {apps.length === 0 && !error ? (
        <List.EmptyView
          title="No Managed Apps"
          description="Manage apps with GhostTile first, then control them from Raycast."
          icon={ghostTileIcon()}
        />
      ) : null}

      {apps.map((app) => (
        <List.Item
          key={app.bundleId}
          id={app.bundleId}
          title={app.name}
          subtitle={app.bundleId}
          icon={appIcon(app)}
          accessories={[managedAccessory(app)]}
          actions={
            <ActionPanel>
              {app.running ? (
                <Action
                  title="Focus App"
                  icon={Icon.ArrowClockwise}
                  onAction={() => void runAction(`Focusing ${app.name}`, ["focus", app.bundleId])}
                />
              ) : null}

              {app.running && app.hiddenFromDock ? (
                <Action
                  title="Show in Dock"
                  icon={Icon.Eye}
                  onAction={() => void runAction(`Showing ${app.name}`, ["show", app.bundleId])}
                />
              ) : null}

              {app.running && !app.hiddenFromDock ? (
                <Action
                  title="Hide from Dock"
                  icon={Icon.EyeDisabled}
                  onAction={() => void runAction(`Hiding ${app.name}`, ["hide", app.bundleId])}
                />
              ) : null}

              <Action
                title="Restore App"
                icon={Icon.Trash}
                onAction={() => void runAction(`Restoring ${app.name}`, ["restore", app.bundleId])}
              />

              <Action
                title="Refresh"
                icon={Icon.ArrowClockwise}
                onAction={() => void refresh()}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function managedStateLabel(app: GhostTileAppRecord): string {
  if (!app.running) {
    return "Not Running";
  }

  return app.hiddenFromDock ? "Hidden" : "Visible";
}

function managedAccessory(app: GhostTileAppRecord): List.Item.Accessory {
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

function appIcon(app: GhostTileAppRecord): Image.ImageLike {
  if (app.appPath.length > 0) {
    return {
      fileIcon: app.appPath,
      fallback: app.hiddenFromDock ? Icon.EyeDisabled : Icon.AppWindow,
    };
  }

  return app.hiddenFromDock ? Icon.EyeDisabled : Icon.AppWindow;
}

function ghostTileIcon(): Image.ImageLike {
  return {
    source: "assets/extension-icon.png",
    fallback: Icon.EyeDisabled,
  };
}

function summarizeOutput(output: string): string | undefined {
  const lines = output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  return lines.at(-1);
}
