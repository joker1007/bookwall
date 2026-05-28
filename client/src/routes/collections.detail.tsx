import { useState } from "react";
import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Pencil } from "lucide-react";
import { Button } from "@/components/ui/button";
import { BookListView } from "@/components/books/BookListView";
import { CollectionFormDialog } from "@/components/collections/CollectionFormDialog";
import { DeleteCollectionButton } from "@/components/collections/DeleteCollectionButton";
import { useCollection, useUpdateCollection } from "@/hooks/useCollections";

export default function CollectionDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const collectionQuery = useCollection(id);
  const collection = collectionQuery.data;
  const update = useUpdateCollection();
  const [renameOpen, setRenameOpen] = useState(false);

  const handleRename = (name: string) => {
    if (!id) return;
    update.mutate({ id, name }, { onSuccess: () => setRenameOpen(false) });
  };

  const headerActions = collection ? (
    <>
      <Button
        variant="outline"
        size="sm"
        className="gap-2"
        onClick={() => setRenameOpen(true)}
      >
        <Pencil className="size-4" aria-hidden />
        {t("collections.rename")}
      </Button>
      <DeleteCollectionButton collection={collection} />
    </>
  ) : null;

  return (
    <>
      <BookListView
        title={collection?.name ?? t("collections.title")}
        baseParams={{ collection_id: id }}
        emptyMessage={t("collections.detailEmpty")}
        headerActions={headerActions}
      />
      <CollectionFormDialog
        open={renameOpen}
        onOpenChange={setRenameOpen}
        title={t("collections.renameTitle")}
        submitLabel={t("common.save")}
        pendingLabel={t("common.saving")}
        initialName={collection?.name ?? ""}
        pending={update.isPending}
        error={update.error}
        onSubmit={handleRename}
      />
    </>
  );
}
