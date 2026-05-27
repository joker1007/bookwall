import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function AuthorDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  return <BookListView title={t("books.list.byAuthor")} baseParams={{ author_id: id }} />;
}
