import { useParams } from "react-router-dom";
import { BookListView } from "@/components/books/BookListView";

export default function SeriesDetailPage() {
  const { id } = useParams();
  return (
    <BookListView title="シリーズの書籍" baseParams={{ series_id: id }} />
  );
}
