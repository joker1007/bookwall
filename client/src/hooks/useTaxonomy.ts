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

function buildQuery(params: Record<string, string | number | undefined | null>) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === "") continue;
    if (key === "page" && value === 1) continue;
    search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : "";
}

interface SeriesListParams {
  page?: number;
  limit?: number;
  library_id?: number | string;
}

export function useSeriesList(params: number | SeriesListParams = {}) {
  // Back-compat: callers used to pass `page` as a bare number.
  const resolved: SeriesListParams =
    typeof params === "number" ? { page: params } : params;
  const { page = 1, limit, library_id } = resolved;
  const qs = buildQuery({ page, limit, library_id });

  return useQuery<SeriesListResponse>({
    queryKey: ["series", { page, limit, library_id }],
    queryFn: () => api<SeriesListResponse>(`/api/series${qs}`),
  });
}

interface AuthorsListParams {
  page?: number;
  limit?: number;
}

export function useAuthorsList(params: number | AuthorsListParams = {}) {
  const resolved: AuthorsListParams =
    typeof params === "number" ? { page: params } : params;
  const { page = 1, limit } = resolved;
  const qs = buildQuery({ page, limit });

  return useQuery<AuthorsListResponse>({
    queryKey: ["authors", { page, limit }],
    queryFn: () => api<AuthorsListResponse>(`/api/authors${qs}`),
  });
}

interface TagsListParams {
  page?: number;
  limit?: number;
}

export function useTagsList(params: number | TagsListParams = {}) {
  const resolved: TagsListParams =
    typeof params === "number" ? { page: params } : params;
  const { page = 1, limit } = resolved;
  const qs = buildQuery({ page, limit });

  return useQuery<TagsListResponse>({
    queryKey: ["tags", { page, limit }],
    queryFn: () => api<TagsListResponse>(`/api/tags${qs}`),
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
