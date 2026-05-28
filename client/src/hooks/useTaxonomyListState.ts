import { useSearchParams } from "react-router-dom";
import { useUiStore, PER_PAGE_OPTIONS, type PerPage } from "@/stores/uiStore";

// Shared state for the grid-style taxonomy list pages (Series, Authors, a
// library's series view): the `?page` URL param plus the persisted perPage /
// itemSize preferences, and the handlers that keep them consistent (changing
// page size resets to page 1 so the "what am I looking at" anchor is stable).
export function useTaxonomyListState() {
  const [searchParams, setSearchParams] = useSearchParams();
  const itemSize = useUiStore((s) => s.itemSize);
  const setItemSize = useUiStore((s) => s.setItemSize);
  const perPage = useUiStore((s) => s.perPage);
  const setPerPage = useUiStore((s) => s.setPerPage);

  const page = parseInt(searchParams.get("page") ?? "1", 10) || 1;

  const updatePage = (next: number) => {
    const params = new URLSearchParams(searchParams);
    if (next === 1) params.delete("page");
    else params.set("page", String(next));
    setSearchParams(params);
  };

  const handlePerPageChange = (value: string) => {
    const next = Number(value) as PerPage;
    if (!PER_PAGE_OPTIONS.includes(next)) return;
    setPerPage(next);
    if (page !== 1) updatePage(1);
  };

  return { page, perPage, itemSize, setItemSize, updatePage, handlePerPageChange };
}
