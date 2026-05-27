import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";

export default function HomePage() {
  const { t } = useTranslation();
  return (
    <BookListView
      title={t("home.title")}
      description={t("home.description")}
      emptyMessage={t("home.empty")}
    />
  );
}
