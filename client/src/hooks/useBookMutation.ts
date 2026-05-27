import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Book } from "@/types/api";

export interface UpdateBookInput {
  id: number;
  title?: string;
  volume?: number | null;
  series_id?: number | null;
  published_at?: string | null;
  page_count?: number | null;
  author_names?: string[];
  tag_names?: string[];
}

export function useUpdateBook() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...payload }: UpdateBookInput) =>
      api<Book>(`/api/books/${id}`, { method: "PATCH", body: payload }),
    onSuccess: (book) => {
      queryClient.invalidateQueries({ queryKey: ["books"] });
      queryClient.setQueryData(["book", String(book.id)], book);
    },
  });
}

export function useDeleteBook() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => api(`/api/books/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["books"] });
    },
  });
}
