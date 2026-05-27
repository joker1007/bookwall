import { create } from "zustand";
import { persist } from "zustand/middleware";

export type DisplayMode = "grid" | "list";

interface UiState {
  displayMode: DisplayMode;
  // Last sort order the user picked in any BookListView. Used as the
  // fallback when a page's URL doesn't carry `?sort=`, so navigating
  // between book lists carries the preference along.
  sortOrder: string;
  sidebarOpen: boolean;
  setDisplayMode: (mode: DisplayMode) => void;
  setSortOrder: (sort: string) => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
}

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      displayMode: "grid",
      sortOrder: "added_at_desc",
      sidebarOpen: false,
      setDisplayMode: (mode) => set({ displayMode: mode }),
      setSortOrder: (sort) => set({ sortOrder: sort }),
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
    }),
    {
      name: "bookwall-ui",
      partialize: (state) => ({
        displayMode: state.displayMode,
        sortOrder: state.sortOrder,
      }),
    }
  )
);
