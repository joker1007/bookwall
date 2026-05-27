import { useParams } from "react-router-dom";
import { BookListView } from "@/components/books/BookListView";

export default function AuthorDetailPage() {
  const { id } = useParams();
  return <BookListView title="著者の書籍" baseParams={{ author_id: id }} />;
}
