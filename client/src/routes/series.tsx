import { useTranslation } from "react-i18next";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { TaxonomyListView } from "@/components/taxonomy/TaxonomyListView";
import { useTaxonomyListState } from "@/hooks/useTaxonomyListState";
import { useSeriesList } from "@/hooks/useTaxonomy";

export default function SeriesIndexPage() {
  const { t } = useTranslation();
  const { page, perPage, itemSize, setItemSize, updatePage, handlePerPageChange } =
    useTaxonomyListState();
  const query = useSeriesList({ page, limit: perPage });

  return (
    <TaxonomyListView
      title={t("series.title")}
      description={t("series.description")}
      emptyMessage={t("series.empty")}
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
