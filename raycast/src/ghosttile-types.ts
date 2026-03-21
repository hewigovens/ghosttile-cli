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
