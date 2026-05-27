import { useSearchParams } from "react-router-dom";
import { BookListView } from "@/components/books/BookListView";

export default function SearchPage() {
  const [params] = useSearchParams();
  const q = params.get("q") ?? "";

  if (!q) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-8">
        <h1 className="text-2xl font-semibold tracking-tight">検索</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          上の検索バーにタイトル / 著者 / タグを入力して Enter してください。
        </p>
      </section>
    );
  }

  return (
    <BookListView
      title={`検索結果: ${q}`}
      description="タイトル・シリーズ名・著者名から AND 検索しています。"
      baseParams={{ q }}
      emptyMessage="該当する書籍が見つかりませんでした。"
    />
  );
}
