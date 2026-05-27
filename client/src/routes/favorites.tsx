import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function FavoritesPage() {
  const { t } = useTranslation();
  return (
    <BookListView
      title={t("books.list.favorites")}
      baseParams={{ favorites_only: true }}
      emptyMessage={t("books.list.favoritesEmpty")}
    />
  );
}
