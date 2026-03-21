import { Action, ActionPanel, Icon, List } from "@raycast/api";
import { appIcon, managedAccessory } from "./ghosttile-presentation";
import { GhostTileAppRecord } from "./ghosttile-types";

type ManagedAppItemProps = {
  app: GhostTileAppRecord;
  onRunAction: (title: string, args: string[]) => void;
  onRefresh: () => void;
};

export function ManagedAppItem({ app, onRunAction, onRefresh }: ManagedAppItemProps) {
  return (
    <List.Item
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
              onAction={() => onRunAction(`Focusing ${app.name}`, ["focus", app.bundleId])}
            />
          ) : null}

          {app.running && app.hiddenFromDock ? (
            <Action
              title="Show in Dock"
              icon={Icon.Eye}
              onAction={() => onRunAction(`Showing ${app.name}`, ["show", app.bundleId])}
            />
          ) : null}

          {app.running && !app.hiddenFromDock ? (
            <Action
              title="Hide from Dock"
              icon={Icon.EyeDisabled}
              onAction={() => onRunAction(`Hiding ${app.name}`, ["hide", app.bundleId])}
            />
          ) : null}

          <Action
            title="Restore App"
            icon={Icon.Trash}
            onAction={() => onRunAction(`Restoring ${app.name}`, ["restore", app.bundleId])}
          />

          <Action
            title="Refresh"
            icon={Icon.ArrowClockwise}
            onAction={onRefresh}
          />
        </ActionPanel>
      }
    />
  );
}
