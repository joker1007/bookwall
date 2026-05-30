import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ReaderSettings, ReadingProgress } from "@/types/api";

export interface UpdateProgressInput {
  current_page?: number;
  epub_cfi?: string;
  progress_fraction?: number;
  settings?: ReaderSettings;
}

const key = (bookId: number | string) => ["progress", String(bookId)] as const;

export function useReadingProgress(bookId: number | string | undefined) {
  return useQuery<ReadingProgress>({
    queryKey: bookId !== undefined ? key(bookId) : ["progress", "_"],
    enabled: bookId !== undefined,
    queryFn: () => api<ReadingProgress>(`/api/books/${bookId}/progress`),
  });
}

export function useUpdateReadingProgress(bookId: number | string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: UpdateProgressInput) =>
      api<ReadingProgress>(`/api/books/${bookId}/progress`, {
        method: "PATCH",
        body: payload,
      }),
    onSuccess: (data) => {
      queryClient.setQueryData<ReadingProgress>(key(bookId), data);
      // Home carousel orders by last_read_at, which this just bumped.
      queryClient.invalidateQueries({ queryKey: ["recent_reads"] });
    },
  });
}
