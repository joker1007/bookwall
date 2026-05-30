import { useSearchParams, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { BookListView } from "@/components/books/BookListView";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { TaxonomyListView } from "@/components/taxonomy/TaxonomyListView";
import { useTaxonomyListState } from "@/hooks/useTaxonomyListState";
import { useLibrary } from "@/hooks/useLibraries";
import { useSeriesList } from "@/hooks/useTaxonomy";

type GroupMode = "books" | "series";

export default function LibraryDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const library = useLibrary(id);
  const [searchParams, setSearchParams] = useSearchParams();
  const groupMode: GroupMode =
    searchParams.get("view") === "series" ? "series" : "books";

  const setGroupMode = (next: GroupMode) => {
    const params = new URLSearchParams(searchParams);
    if (next === "books") params.delete("view");
    else params.set("view", next);
    // Book and series pages share the `?page` slot, so reset it on switch.
    params.delete("page");
    setSearchParams(params, { replace: false });
  };

  const groupToggle = (
    <ToggleGroup
      type="single"
      value={groupMode}
      onValueChange={(v) => {
        if (v === "books" || v === "series") setGroupMode(v);
      }}
      variant="outline"
      aria-label={t("books.groupMode.label")}
    >
      <ToggleGroupItem value="books" className="h-10 px-3 text-sm">
        {t("books.groupMode.books")}
      </ToggleGroupItem>
      <ToggleGroupItem value="series" className="h-10 px-3 text-sm">
        {t("books.groupMode.series")}
      </ToggleGroupItem>
    </ToggleGroup>
  );

  if (groupMode === "series") {
    return (
      <LibrarySeriesGrid
        libraryId={id}
        title={library.data?.name ?? t("books.list.byLibrary")}
        description={library.data?.path}
        headerActions={groupToggle}
      />
    );
  }

  return (
    <BookListView
      title={library.data?.name ?? t("books.list.byLibrary")}
      description={library.data?.path}
      baseParams={{ library_id: id }}
      headerActions={groupToggle}
    />
  );
}

interface LibrarySeriesGridProps {
  libraryId: string | undefined;
  title: string;
  description?: string;
  headerActions: React.ReactNode;
}

function LibrarySeriesGrid({
  libraryId,
  title,
  description,
  headerActions,
}: LibrarySeriesGridProps) {
  const { t } = useTranslation();
  const { page, perPage, itemSize, setItemSize, updatePage, handlePerPageChange } =
    useTaxonomyListState();
  const query = useSeriesList({ page, limit: perPage, library_id: libraryId });

  return (
    <TaxonomyListView
      title={title}
      description={description}
      emptyMessage={t("series.empty")}
      headerActions={headerActions}
      itemSize={itemSize}
      perPage={perPage}
      onItemSizeChange={setItemSize}
      onPerPageChange={handlePerPageChange}
      isPending={query.isPending}
      isError={query.isError}
      items={query.data?.series}
      pagination={query.data?.pagination}
      onPageChange={updatePage}
      getKey={(s) => s.id}
      renderItem={(s) => (
        <TaxonomyCard
          to={`/series/${s.id}`}
          name={s.name}
          thumbUrl={s.sample_cover_thumb_url}
          meta={t("series.bookCount", { count: s.book_count })}
        />
      )}
    />
  );
}
