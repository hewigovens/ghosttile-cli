import { Action, ActionPanel, List, Toast, showToast } from "@raycast/api";
import { runGhosttile } from "./ghosttile";
import { ManagedAppItem } from "./managed-app-item";
import { ghostTileIcon, summarizeOutput } from "./ghosttile-presentation";
import { useManagedApps } from "./use-managed-apps";

export default function Command() {
  const { apps, error, isLoading, refresh } = useManagedApps();

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
        <ManagedAppItem
          key={app.bundleId}
          app={app}
          onRunAction={(title, args) => void runAction(title, args)}
          onRefresh={() => void refresh()}
        />
      ))}
    </List>
  );
}
