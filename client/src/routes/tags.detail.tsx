import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function TagDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  return <BookListView title={t("books.list.byTag")} baseParams={{ tag_id: id }} />;
}
