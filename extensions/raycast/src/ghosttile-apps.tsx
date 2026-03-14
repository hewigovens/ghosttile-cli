import { Action, ActionPanel, Icon, List, Toast, showToast } from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import { GhostTileAppRecord, loadGhostTileApps, revealInFinder, runGhosttile } from "./ghosttile";

type GhostTileState = {
  managed: GhostTileAppRecord[];
  running: GhostTileAppRecord[];
};

export default function Command() {
  const [apps, setApps] = useState<GhostTileState>({ managed: [], running: [] });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string>();

  const refresh = useCallback(async () => {
    setIsLoading(true);
    try {
      const nextApps = await loadGhostTileApps();
      setApps(nextApps);
      setError(undefined);
    } catch (refreshError) {
      setError(refreshError instanceof Error ? refreshError.message : "Failed to load GhostTile apps.");
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

  async function reveal(appPath: string): Promise<void> {
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Revealing in Finder",
    });

    try {
      await revealInFinder(appPath);
      toast.style = Toast.Style.Success;
    } catch (revealError) {
      toast.style = Toast.Style.Failure;
      toast.message = revealError instanceof Error ? revealError.message : "Failed to reveal app in Finder.";
    }
  }

  return (
    <List isLoading={isLoading}>
      {error ? (
        <List.Item
          id="ghosttile-error"
          title="GhostTile command failed"
          subtitle={error}
          actions={
            <ActionPanel>
              <Action title="Retry" onAction={() => void refresh()} />
            </ActionPanel>
          }
        />
      ) : null}

      <List.Section title={`Managed Apps (${apps.managed.length})`}>
        {apps.managed.map((app) => (
          <List.Item
            key={app.bundleId}
            id={app.bundleId}
            title={app.name}
            subtitle={app.bundleId}
            icon={app.running ? (app.hiddenFromDock ? Icon.EyeDisabled : Icon.AppWindow) : Icon.Circle}
            accessories={[{ text: managedStateLabel(app) }]}
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
                  title="Reveal in Finder"
                  icon={Icon.Finder}
                  onAction={() => void reveal(app.appPath)}
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
      </List.Section>

      <List.Section title={`Running Apps (${apps.running.length})`}>
        {apps.running.map((app) => (
          <List.Item
            key={app.bundleId}
            id={`running-${app.bundleId}`}
            title={app.name}
            subtitle={app.bundleId}
            icon={Icon.AppWindow}
            accessories={[{ text: "Visible" }]}
            actions={
              <ActionPanel>
                <Action
                  title="Hide with GhostTile"
                  icon={Icon.EyeDisabled}
                  onAction={() => void runAction(`Managing ${app.name}`, ["manage", app.appPath])}
                />

                <Action
                  title="Reveal in Finder"
                  icon={Icon.Finder}
                  onAction={() => void reveal(app.appPath)}
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
      </List.Section>
    </List>
  );
}

function managedStateLabel(app: GhostTileAppRecord): string {
  if (!app.running) {
    return "Not Running";
  }

  return app.hiddenFromDock ? "Hidden" : "Visible";
}

function summarizeOutput(output: string): string | undefined {
  const lines = output
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  return lines.at(-1);
}
