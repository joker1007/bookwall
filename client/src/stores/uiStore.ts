import { create } from "zustand";
import { persist } from "zustand/middleware";

export type DisplayMode = "grid" | "list";

interface UiState {
  displayMode: DisplayMode;
  sidebarOpen: boolean;
  setDisplayMode: (mode: DisplayMode) => void;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
}

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      displayMode: "grid",
      sidebarOpen: false,
      setDisplayMode: (mode) => set({ displayMode: mode }),
      toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
      setSidebarOpen: (open) => set({ sidebarOpen: open }),
    }),
    {
      name: "bookwall-ui",
      partialize: (state) => ({
        displayMode: state.displayMode,
      }),
    }
  )
);
