import { BookListView } from "@/components/books/BookListView";

export default function HomePage() {
  return (
    <BookListView
      title="ホーム"
      description="最近追加された書籍。"
      emptyMessage="まだ書籍がありません。設定からライブラリを追加してスキャンしてみてください。"
    />
  );
}
