import { useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, ApiError } from "@/lib/api";
import { useAuthStore } from "@/stores/authStore";
import { REGISTRATION_SETTINGS_KEY } from "@/hooks/useRegistrationSettings";
import type { User } from "@/types/api";

const SESSION_KEY = ["session"] as const;

export function useSessionBootstrap() {
  const setUser = useAuthStore((s) => s.setUser);
  const setStatus = useAuthStore((s) => s.setStatus);

  const query = useQuery<User | null>({
    queryKey: SESSION_KEY,
    queryFn: async () => {
      try {
        return await api<User>("/api/session");
      } catch (e) {
        if (e instanceof ApiError && e.status === 401) return null;
        throw e;
      }
    },
    staleTime: 60_000,
  });

  useEffect(() => {
    if (query.isPending) {
      setStatus("loading");
      return;
    }
    setUser(query.data ?? null);
  }, [query.data, query.isPending, setStatus, setUser]);

  return query;
}

interface LoginInput {
  email_address: string;
  password: string;
}

export function useLogin() {
  const queryClient = useQueryClient();
  const setUser = useAuthStore((s) => s.setUser);

  return useMutation({
    mutationFn: (input: LoginInput) =>
      api<User>("/api/session", { method: "POST", body: input }),
    onSuccess: (user) => {
      setUser(user);
      queryClient.setQueryData(SESSION_KEY, user);
    },
  });
}

interface RegistrationInput {
  email_address: string;
  password: string;
  password_confirmation: string;
}

export function useRegister() {
  const queryClient = useQueryClient();
  const setUser = useAuthStore((s) => s.setUser);

  return useMutation({
    mutationFn: (input: RegistrationInput) =>
      api<User>("/api/registrations", { method: "POST", body: input }),
    onSuccess: (user) => {
      setUser(user);
      queryClient.setQueryData(SESSION_KEY, user);
      queryClient.invalidateQueries({ queryKey: REGISTRATION_SETTINGS_KEY });
    },
  });
}

export function useLogout() {
  const queryClient = useQueryClient();
  const setUser = useAuthStore((s) => s.setUser);

  return useMutation({
    mutationFn: () => api<void>("/api/session", { method: "DELETE" }),
    onSuccess: () => {
      setUser(null);
      queryClient.setQueryData(SESSION_KEY, null);
      queryClient.removeQueries({ queryKey: ["books"] });
    },
  });
}
