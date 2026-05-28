import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Collection, CollectionsListResponse } from "@/types/api";

interface CollectionListParams {
  page?: number;
  limit?: number;
}

function buildQuery(params: Record<string, number | undefined>) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined) continue;
    if (key === "page" && value === 1) continue;
    search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : "";
}

export function useCollectionsList(params: CollectionListParams = {}) {
  const { page = 1, limit } = params;
  const qs = buildQuery({ page, limit });
  return useQuery<CollectionsListResponse>({
    queryKey: ["collections", { page, limit }],
    queryFn: () => api<CollectionsListResponse>(`/api/collections${qs}`),
  });
}

export function useCollection(id: number | string | undefined) {
  return useQuery<Collection>({
    queryKey: ["collection", "detail", id],
    queryFn: () => api<Collection>(`/api/collections/${id}`),
    enabled: id !== undefined,
  });
}

export function useCreateCollection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (name: string) =>
      api<Collection>("/api/collections", { method: "POST", body: { name } }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["collections"] });
    },
  });
}

export function useUpdateCollection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, name }: { id: number | string; name: string }) =>
      api<Collection>(`/api/collections/${id}`, { method: "PATCH", body: { name } }),
    onSuccess: () => {
      // Both the list and any detail query reflect a rename.
      queryClient.invalidateQueries({ queryKey: ["collections"] });
      queryClient.invalidateQueries({ queryKey: ["collection"] });
    },
  });
}

export function useDeleteCollection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number | string) => api(`/api/collections/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["collections"] });
      queryClient.invalidateQueries({ queryKey: ["books"] });
    },
  });
}

export function useAddBooksToCollection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ collectionId, bookIds }: { collectionId: number | string; bookIds: number[] }) =>
      api(`/api/collections/${collectionId}/books`, { method: "POST", body: { book_ids: bookIds } }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["collections"] });
      queryClient.invalidateQueries({ queryKey: ["books"] });
    },
  });
}

export function useRemoveBookFromCollection() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ collectionId, bookId }: { collectionId: number | string; bookId: number }) =>
      api(`/api/collections/${collectionId}/books/${bookId}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["collections"] });
      queryClient.invalidateQueries({ queryKey: ["books"] });
    },
  });
}
