import { Fragment, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { ItemSizeSlider } from "@/components/common/ItemSizeSlider";
import { GridSkeleton } from "@/components/common/GridSkeleton";
import { Pagination } from "@/components/common/Pagination";
import { PER_PAGE_OPTIONS } from "@/stores/uiStore";
import type { Pagination as PaginationMeta } from "@/types/api";

interface TaxonomyListViewProps<T> {
  title: string;
  description?: string;
  emptyMessage: string;
  headerActions?: ReactNode;
  itemSize: number;
  perPage: number;
  onItemSizeChange: (next: number) => void;
  onPerPageChange: (value: string) => void;
  isPending: boolean;
  isError: boolean;
  items: T[] | undefined;
  pagination: PaginationMeta | undefined;
  onPageChange: (page: number) => void;
  getKey: (item: T) => React.Key;
  renderItem: (item: T) => ReactNode;
}

export function TaxonomyListView<T>({
  title,
  description,
  emptyMessage,
  headerActions,
  itemSize,
  perPage,
  onItemSizeChange,
  onPerPageChange,
  isPending,
  isError,
  items,
  pagination,
  onPageChange,
  getKey,
  renderItem,
}: TaxonomyListViewProps<T>) {
  const { t } = useTranslation();

  return (
    <section className="flex flex-col gap-4 px-3 py-6">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 flex-col gap-2">
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">{title}</h1>
          {description ? (
            <p className="text-sm text-muted-foreground">{description}</p>
          ) : null}
        </div>
        {headerActions ? (
          <div className="flex shrink-0 items-center gap-2">{headerActions}</div>
        ) : null}
      </header>

      <div className="flex flex-wrap items-center gap-2">
        <Select value={String(perPage)} onValueChange={onPerPageChange}>
          <SelectTrigger className="h-10 w-28" aria-label={t("books.perPage.label")}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {PER_PAGE_OPTIONS.map((n) => (
              <SelectItem key={n} value={String(n)}>
                {t("books.perPage.option", { count: n })}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <ItemSizeSlider value={itemSize} onChange={onItemSizeChange} />
      </div>

      {isPending ? (
        <GridSkeleton itemSize={itemSize} />
      ) : isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : !items || items.length === 0 ? (
        <p className="rounded-lg border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
          {emptyMessage}
        </p>
      ) : (
        <>
          <div
            className="grid gap-3"
            style={{
              gridTemplateColumns: `repeat(auto-fill, minmax(${itemSize}px, 1fr))`,
            }}
          >
            {items.map((item) => (
              <Fragment key={getKey(item)}>{renderItem(item)}</Fragment>
            ))}
          </div>
          {pagination ? (
            <Pagination
              page={pagination.page}
              pages={pagination.pages}
              onPageChange={onPageChange}
            />
          ) : null}
        </>
      )}
    </section>
  );
}
