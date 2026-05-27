import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { Author, Pagination, Series, Tag } from "@/types/api";

interface SeriesListResponse {
  series: Series[];
  pagination: Pagination;
}

interface AuthorsListResponse {
  authors: Author[];
  pagination: Pagination;
}

interface TagsListResponse {
  tags: Tag[];
  pagination: Pagination;
}

function withPage(path: string, page: number | undefined) {
  if (!page || page === 1) return path;
  return `${path}?page=${page}`;
}

interface SeriesListParams {
  page?: number;
  library_id?: number | string;
}

export function useSeriesList(params: number | SeriesListParams = {}) {
  // Back-compat: callers used to pass `page` as a bare number.
  const resolved: SeriesListParams =
    typeof params === "number" ? { page: params } : params;
  const { page = 1, library_id } = resolved;

  const path = (() => {
    const search = new URLSearchParams();
    if (page > 1) search.set("page", String(page));
    if (library_id !== undefined) search.set("library_id", String(library_id));
    const qs = search.toString();
    return qs ? `/api/series?${qs}` : "/api/series";
  })();

  return useQuery<SeriesListResponse>({
    queryKey: ["series", { page, library_id }],
    queryFn: () => api<SeriesListResponse>(path),
  });
}

export function useAuthorsList(page = 1) {
  return useQuery<AuthorsListResponse>({
    queryKey: ["authors", page],
    queryFn: () => api<AuthorsListResponse>(withPage("/api/authors", page)),
  });
}

export function useTagsList(page = 1) {
  return useQuery<TagsListResponse>({
    queryKey: ["tags", page],
    queryFn: () => api<TagsListResponse>(withPage("/api/tags", page)),
  });
}

export function useSeries(id: number | string | undefined) {
  return useQuery<Series>({
    queryKey: ["series", "detail", id],
    queryFn: () => api<Series>(`/api/series/${id}`),
    enabled: id !== undefined,
  });
}

export function useDeleteSeries() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number | string) =>
      api(`/api/series/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      // Series listings + the books that lived under the deleted series all
      // change at once, so invalidate broadly.
      queryClient.invalidateQueries({ queryKey: ["series"] });
      queryClient.invalidateQueries({ queryKey: ["books"] });
    },
  });
}
