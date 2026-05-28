import { useTranslation } from "react-i18next";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { TaxonomyListView } from "@/components/taxonomy/TaxonomyListView";
import { useTaxonomyListState } from "@/hooks/useTaxonomyListState";
import { useAuthorsList } from "@/hooks/useTaxonomy";

export default function AuthorsIndexPage() {
  const { t } = useTranslation();
  const { page, perPage, itemSize, setItemSize, updatePage, handlePerPageChange } =
    useTaxonomyListState();
  const query = useAuthorsList({ page, limit: perPage });

  return (
    <TaxonomyListView
      title={t("authors.title")}
      description={t("authors.description")}
      emptyMessage={t("authors.empty")}
      itemSize={itemSize}
      perPage={perPage}
      onItemSizeChange={setItemSize}
      onPerPageChange={handlePerPageChange}
      isPending={query.isPending}
      isError={query.isError}
      items={query.data?.authors}
      pagination={query.data?.pagination}
      onPageChange={updatePage}
      getKey={(a) => a.id}
      renderItem={(a) => (
        <TaxonomyCard
          to={`/authors/${a.id}`}
          name={a.name}
          thumbUrl={a.sample_cover_thumb_url}
          meta={t("authors.bookCount", { count: a.book_count })}
        />
      )}
    />
  );
}
