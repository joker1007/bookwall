import { useMutation, useQueryClient, type QueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { BookRefreshTarget } from "@/hooks/useBookMutation";

function invalidateAfterBulk(queryClient: QueryClient) {
  return () => {
    queryClient.invalidateQueries({ queryKey: ["books"] });
    queryClient.invalidateQueries({ queryKey: ["recent_favorites"] });
    queryClient.invalidateQueries({ queryKey: ["recent_reads"] });
    queryClient.invalidateQueries({ queryKey: ["collections"] });
  };
}

export function useBulkFavorite() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (bookIds: number[]) =>
      api("/api/books/bulk_favorite", { method: "POST", body: { book_ids: bookIds } }),
    onSuccess: invalidateAfterBulk(queryClient),
  });
}

export function useBulkUnfavorite() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (bookIds: number[]) =>
      api("/api/books/bulk_favorite", { method: "DELETE", body: { book_ids: bookIds } }),
    onSuccess: invalidateAfterBulk(queryClient),
  });
}

export function useBulkDestroy() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (bookIds: number[]) =>
      api("/api/books/bulk_destroy", { method: "POST", body: { book_ids: bookIds } }),
    onSuccess: invalidateAfterBulk(queryClient),
  });
}

export function useBulkRefresh() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ bookIds, target }: { bookIds: number[]; target: BookRefreshTarget }) =>
      api<{ queued: number }>(`/api/books/bulk_${target}`, {
        method: "POST",
        body: { book_ids: bookIds },
      }),
    onSuccess: invalidateAfterBulk(queryClient),
  });
}
