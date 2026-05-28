import { useMemo } from "react";
import type { ReaderSettings } from "@/types/api";
import { useReadingProgress } from "@/hooks/useReadingProgress";
import { useUserPreferences } from "@/hooks/useUserPreferences";

export interface ResolvedReaderSettings {
  // Per-book settings layered over the user's reader_defaults: any field a
  // book hasn't explicitly saved falls through to the default rather than
  // to a reader's hard-coded initial value. The persisted hash is `{}`
  // until settings are saved, so merging (not `persisted ?? defaults`) is
  // what keeps the defaults visible for a book that's been opened — its
  // progress row exists from a page / location save — but never had its
  // reader settings touched.
  settings: ReaderSettings;
  currentPage: number;
  // True once BOTH queries have settled (resolved or errored). Gating on
  // "settled" rather than "has data" means an errored query degrades to
  // defaults instead of leaving the reader stuck on its loading screen.
  ready: boolean;
}

// Single source of truth for resolving the settings a reader should start
// with. Both the image/CBZ reader and the EPUB reader consume this so the
// merge rule and the restore gate can't drift apart (a past divergence here
// dropped the defaults on reload). Each reader still pulls its own fields
// (spread/direction/scale vs font_size/theme/writing_mode) off `settings`.
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
