import { useQuery, type UseQueryOptions } from "@tanstack/react-query";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Book, Pagination } from "@/types/api";

export interface BookListParams {
  q?: string;
  library_id?: number | string;
  series_id?: number | string;
  author_id?: number | string;
  tag_id?: number | string;
  favorites_only?: boolean;
  sort?: string;
  page?: number;
}

export interface BookListResponse {
  books: Book[];
  pagination: Pagination;
}

function cleanParams(params: BookListParams): Record<string, string | number | boolean> {
  const out: Record<string, string | number | boolean> = {};
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue;
    if (typeof value === "boolean" && !value) continue;
    out[key] = value as string | number | boolean;
  }
  return out;
}

export function useBookList(
  params: BookListParams,
  options?: Omit<UseQueryOptions<BookListResponse>, "queryKey" | "queryFn">
) {
  const cleaned = cleanParams(params);
  return useQuery<BookListResponse>({
    queryKey: ["books", cleaned],
    queryFn: () => api<BookListResponse>("/api/books", { params: cleaned }),
    placeholderData: (previous) => previous,
    ...options,
  });
}

export function useRecentReads() {
  return useQuery<{ books: Book[] }>({
    queryKey: ["recent_reads"],
    queryFn: () => api<{ books: Book[] }>("/api/recent_reads"),
  });
}

export function useRecentFavorites() {
  return useQuery<{ books: Book[] }>({
    queryKey: ["recent_favorites"],
    queryFn: () => api<{ books: Book[] }>("/api/recent_favorites"),
  });
}

export function useBook(id: number | string | undefined) {
  return useQuery<Book>({
    queryKey: ["book", String(id)],
    enabled: id !== undefined,
    queryFn: () => api<Book>(`/api/books/${id}`),
  });
}

export function useFavoriteBook() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, favorited }: { id: number; favorited: boolean }) =>
      favorited
        ? api(`/api/books/${id}/favorite`, { method: "DELETE" })
        : api(`/api/books/${id}/favorite`, { method: "POST" }),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: ["books"] });
      queryClient.invalidateQueries({ queryKey: ["book", String(id)] });
      queryClient.invalidateQueries({ queryKey: ["recent_favorites"] });
    },
  });
}
