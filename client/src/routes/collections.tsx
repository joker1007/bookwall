import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { TaxonomyCard } from "@/components/taxonomy/TaxonomyCard";
import { TaxonomyListView } from "@/components/taxonomy/TaxonomyListView";
import { CollectionFormDialog } from "@/components/collections/CollectionFormDialog";
import { useTaxonomyListState } from "@/hooks/useTaxonomyListState";
import { useCollectionsList, useCreateCollection } from "@/hooks/useCollections";

export default function CollectionsIndexPage() {
  const { t } = useTranslation();
  const { page, perPage, itemSize, setItemSize, updatePage, handlePerPageChange } =
    useTaxonomyListState();
  const query = useCollectionsList({ page, limit: perPage });
  const create = useCreateCollection();
  const [createOpen, setCreateOpen] = useState(false);

  const handleCreate = (name: string) => {
    create.mutate(name, { onSuccess: () => setCreateOpen(false) });
  };

  return (
    <>
      <TaxonomyListView
        title={t("collections.title")}
        description={t("collections.description")}
        emptyMessage={t("collections.empty")}
        headerActions={
          <Button size="sm" className="gap-2" onClick={() => setCreateOpen(true)}>
            <Plus className="size-4" aria-hidden />
            {t("collections.create")}
          </Button>
        }
        itemSize={itemSize}
        perPage={perPage}
        onItemSizeChange={setItemSize}
        onPerPageChange={handlePerPageChange}
        isPending={query.isPending}
        isError={query.isError}
        items={query.data?.collections}
        pagination={query.data?.pagination}
        onPageChange={updatePage}
        getKey={(c) => c.id}
        renderItem={(c) => (
          <TaxonomyCard
            to={`/collections/${c.id}`}
            name={c.name}
            thumbUrl={c.sample_cover_thumb_url}
            meta={t("collections.bookCount", { count: c.book_count })}
          />
        )}
      />
      <CollectionFormDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        title={t("collections.createTitle")}
        submitLabel={t("collections.create")}
        pendingLabel={t("common.saving")}
        pending={create.isPending}
        error={create.error}
        onSubmit={handleCreate}
      />
    </>
  );
}
