import { useMemo } from "react";
import type { ReaderSettings } from "@/types/api";
import { useReadingProgress } from "@/hooks/useReadingProgress";
import { useUserPreferences } from "@/hooks/useUserPreferences";

export interface ResolvedReaderSettings {
  // Per-book settings merged over reader_defaults (not `persisted ?? defaults`):
  // the persisted hash is `{}` until saved, so merging keeps defaults visible.
  settings: ReaderSettings;
  currentPage: number;
  // Settled (resolved or errored), so an errored query degrades to defaults.
  ready: boolean;
}

export function useResolvedReaderSettings(
  bookId: number | string | undefined,
): ResolvedReaderSettings {
  const progress = useReadingProgress(bookId);
  const preferences = useUserPreferences();
  const settings = useMemo<ReaderSettings>(
    () => ({
      ...(preferences.data?.reader_defaults ?? {}),
      ...(progress.data?.settings ?? {}),
    }),
    [preferences.data, progress.data],
  );
  return {
    settings,
    currentPage: progress.data?.current_page ?? 0,
    ready: !progress.isPending && !preferences.isPending,
  };
}
