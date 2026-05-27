import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";
import { useLibrary } from "@/hooks/useLibraries";

export default function LibraryDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const library = useLibrary(id);

  return (
    <BookListView
      title={library.data?.name ?? t("books.list.byLibrary")}
      description={library.data?.path}
      baseParams={{ library_id: id }}
    />
  );
}
