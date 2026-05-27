import { useParams } from "react-router-dom";
import { BookListView } from "@/components/books/BookListView";

export default function TagDetailPage() {
  const { id } = useParams();
  return <BookListView title="タグの書籍" baseParams={{ tag_id: id }} />;
}
