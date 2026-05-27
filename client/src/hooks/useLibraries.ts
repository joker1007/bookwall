import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Library, Pagination } from "@/types/api";

interface LibraryListResponse {
  libraries: Library[];
  pagination: Pagination;
}

export function useLibraries() {
  return useQuery<LibraryListResponse>({
    queryKey: ["libraries"],
    queryFn: () => api<LibraryListResponse>("/api/libraries"),
  });
}

export function useCreateLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { name: string; path: string }) =>
      api<Library>("/api/libraries", { method: "POST", body: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["libraries"] }),
  });
}

export function useUpdateLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...payload }: { id: number; name?: string; path?: string }) =>
      api<Library>(`/api/libraries/${id}`, { method: "PATCH", body: payload }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["libraries"] }),
  });
}

export function useDeleteLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api(`/api/libraries/${id}`, { method: "DELETE" }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["libraries"] }),
  });
}

export function useScanLibrary() {
  return useMutation({
    mutationFn: (id: number) =>
      api(`/api/libraries/${id}/scans`, { method: "POST" }),
  });
}
