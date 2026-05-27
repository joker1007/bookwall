import { useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function SearchPage() {
  const { t } = useTranslation();
  const [params] = useSearchParams();
  const q = params.get("q") ?? "";

  if (!q) {
    return (
      <section className="mx-auto max-w-5xl px-4 py-8">
        <h1 className="text-2xl font-semibold tracking-tight">{t("search.title")}</h1>
        <p className="mt-2 text-sm text-muted-foreground">{t("search.prompt")}</p>
      </section>
    );
  }

  return (
    <BookListView
      title={t("search.resultsTitle", { q })}
      description={t("search.resultsDescription")}
      baseParams={{ q }}
      emptyMessage={t("search.empty")}
    />
  );
}
