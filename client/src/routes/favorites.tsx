import { BookListView } from "@/components/books/BookListView";

export default function FavoritesPage() {
  return (
    <BookListView
      title="お気に入り"
      baseParams={{ favorites_only: true }}
      emptyMessage="お気に入りに追加した書籍はまだありません。"
    />
  );
}
