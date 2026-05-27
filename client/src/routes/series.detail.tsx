import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function SeriesDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  return (
    <BookListView title={t("books.list.bySeries")} baseParams={{ series_id: id }} />
  );
}
