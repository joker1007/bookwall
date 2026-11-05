import { useEffect, useRef } from "react";
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

interface LibraryScansResponse {
  scans: ScanLog[];
}

const isActive = (log: ScanLog | undefined) =>
  log?.status === "pending" || log?.status === "running";

export function useScanLibrary() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) =>
      api<ScanLog>(`/api/libraries/${id}/scans`, { method: "POST" }),
    onSuccess: (log, id) => {
      queryClient.setQueryData<LibraryScansResponse>(["library_scans", id], (prev) => ({
        scans: [log, ...(prev?.scans ?? []).filter((s) => s.id !== log.id)],
      }));
    },
  });
}

export function useLibraryScans(id: number | undefined) {
  const queryClient = useQueryClient();
  const query = useQuery<LibraryScansResponse>({
    queryKey: ["library_scans", id],
    enabled: id !== undefined,
    queryFn: () => api<LibraryScansResponse>(`/api/libraries/${id}/scans`),
    refetchInterval: (query) => (isActive(query.state.data?.scans?.[0]) ? 2000 : false),
  });

  const latest = query.data?.scans?.[0];
  const prevActiveId = useRef<number | null>(null);
  useEffect(() => {
    if (!latest) return;
    if (isActive(latest)) {
      prevActiveId.current = latest.id;
    } else if (prevActiveId.current === latest.id) {
      prevActiveId.current = null;
      // A finished scan can change books, series, authors, tags and last_scanned_at.
      queryClient.invalidateQueries({
        predicate: (q) => q.queryKey[0] !== "library_scans",
      });
    }
  }, [latest, queryClient]);

  return query;
}
