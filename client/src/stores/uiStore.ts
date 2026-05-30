import { create } from "zustand";
import { persist } from "zustand/middleware";

export type DisplayMode = "grid" | "list";

export const PER_PAGE_OPTIONS = [20, 50, 100, 200] as const;
export type PerPage = (typeof PER_PAGE_OPTIONS)[number];

export const ITEM_SIZE_MIN = 120;
export const ITEM_SIZE_MAX = 320;
export const ITEM_SIZE_DEFAULT = 160;

interface UiState {
  displayMode: DisplayMode;
  // Fallback when a page's URL doesn't carry `?sort=`.
  sortOrder: string;
  sidebarOpen: boolean;
  itemSize: number;
  perPage: PerPage;
  setDisplayMode: (mode: DisplayMode) => void;
  setSortOrder: (sort: string) => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
  setItemSize: (size: number) => void;
  setPerPage: (perPage: PerPage) => void;
}

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      displayMode: "grid",
      sortOrder: "added_at_desc",
      sidebarOpen: false,
      itemSize: ITEM_SIZE_DEFAULT,
      perPage: 50,
      setDisplayMode: (mode) => set({ displayMode: mode }),
      setSortOrder: (sort) => set({ sortOrder: sort }),
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
      setItemSize: (size) =>
        set({
          itemSize: Math.min(ITEM_SIZE_MAX, Math.max(ITEM_SIZE_MIN, Math.round(size))),
        }),
      setPerPage: (perPage) => set({ perPage }),
    }),
    {
      name: "bookwall-ui",
      partialize: (state) => ({
        displayMode: state.displayMode,
        sortOrder: state.sortOrder,
        itemSize: state.itemSize,
        perPage: state.perPage,
      }),
    }
  )
);
