import { create } from "zustand";
import type { User } from "@/types/api";

type Status = "idle" | "loading" | "authenticated" | "unauthenticated";

interface AuthState {
  user: User | null;
  status: Status;
  setUser: (user: User | null) => void;
  setStatus: (status: Status) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  status: "idle",
  setUser: (user) =>
    set({
      user,
      status: user ? "authenticated" : "unauthenticated",
    }),
  setStatus: (status) => set({ status }),
}));
