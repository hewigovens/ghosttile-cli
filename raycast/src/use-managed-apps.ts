import { useCallback, useEffect, useState } from "react";
import { loadManagedGhostTileApps } from "./ghosttile-records";
import { GhostTileAppRecord } from "./ghosttile-types";

export function useManagedApps() {
  const [apps, setApps] = useState<GhostTileAppRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string>();

  const refresh = useCallback(async () => {
    setIsLoading(true);
    try {
      const nextApps = await loadManagedGhostTileApps();
      setApps(nextApps);
      setError(undefined);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh().catch((refreshError: unknown) => {
      setError(refreshError instanceof Error ? refreshError.message : "Failed to load managed GhostTile apps.");
      setIsLoading(false);
    });
  }, [refresh]);

  return {
    apps,
    error,
    isLoading,
    refresh,
  };
}
