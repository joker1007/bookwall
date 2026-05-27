import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ApiToken, IssuedApiToken } from "@/types/api";

export function useApiTokens() {
  return useQuery<ApiToken[]>({
    queryKey: ["api_tokens"],
    queryFn: () => api<ApiToken[]>("/api/api_tokens"),
  });
}

export function useIssueApiToken() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { name: string; expires_at?: string | null }) =>
      api<IssuedApiToken>("/api/api_tokens", { method: "POST", body: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["api_tokens"] }),
  });
}

export function useRevokeApiToken() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) =>
      api(`/api/api_tokens/${id}`, { method: "DELETE" }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["api_tokens"] }),
  });
}
