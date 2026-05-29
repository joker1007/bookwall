import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Library, Pagination, ScanLog } from "@/types/api";

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

export function useLibrary(id: number | string | undefined) {
  return useQuery<Library>({
    queryKey: ["library", String(id)],
    enabled: id !== undefined,
    queryFn: () => api<Library>(`/api/libraries/${id}`),
  });
}

export function useCreateLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      name: string;
      path: string;
      shared_user_ids?: number[];
      auto_scan_enabled?: boolean;
    }) => api<Library>("/api/libraries", { method: "POST", body: input }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["libraries"] }),
  });
}

export function useUpdateLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      id,
      ...payload
    }: {
      id: number;
      name?: string;
      path?: string;
      shared_user_ids?: number[];
      auto_scan_enabled?: boolean;
    }) => api<Library>(`/api/libraries/${id}`, { method: "PATCH", body: payload }),
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
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) =>
      api(`/api/libraries/${id}/scans`, { method: "POST" }),
    onSuccess: (_, id) => {
      // Surface the new "running" log in the UI as soon as the worker
      // creates it instead of waiting for the next poll cycle.
      queryClient.invalidateQueries({ queryKey: ["library_scans", id] });
    },
  });
}

interface LibraryScansResponse {
  scans: ScanLog[];
}

// Polls /api/libraries/:id/scans every 2 seconds while a scan is
// running and falls back to a slow (60s) refresh once it's done, so
// the UI shows live progress without hammering the server.
export function useLibraryScans(id: number | undefined) {
  return useQuery<LibraryScansResponse>({
    queryKey: ["library_scans", id],
    enabled: id !== undefined,
    queryFn: () => api<LibraryScansResponse>(`/api/libraries/${id}/scans`),
    refetchInterval: (query) => {
      const latest = query.state.data?.scans?.[0];
      return latest?.status === "running" ? 2000 : false;
    },
  });
}
