import { useEffect } from "react";
import {
  useMutation,
  useQuery,
  useQueryClient,
  type QueryClient,
} from "@tanstack/react-query";
import { api, ApiError } from "@/lib/api";
import { useAuthStore } from "@/stores/authStore";
import { REGISTRATION_SETTINGS_KEY } from "@/hooks/useRegistrationSettings";
import type { User } from "@/types/api";

const SESSION_KEY = ["session"] as const;

const GLOBAL_QUERY_KEYS: ReadonlySet<unknown> = new Set([
  SESSION_KEY[0],
  REGISTRATION_SETTINGS_KEY[0],
]);

// Everything else in the cache belongs to whoever was logged in; drop it on
// any identity change so the next user never sees the previous user's books,
// collections, progress, tokens, etc. Called before the auth store flips so
// no page is still observing the queries being removed.
export function dropUserScopedQueries(queryClient: QueryClient) {
  queryClient.removeQueries({
    predicate: (query) => !GLOBAL_QUERY_KEYS.has(query.queryKey[0]),
  });
}

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
      dropUserScopedQueries(queryClient);
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
      dropUserScopedQueries(queryClient);
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
      dropUserScopedQueries(queryClient);
      setUser(null);
      queryClient.setQueryData(SESSION_KEY, null);
    },
  });
}
