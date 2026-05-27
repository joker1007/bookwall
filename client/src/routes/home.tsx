import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";
import { RecentReadsCarousel } from "@/components/books/RecentReadsCarousel";

export default function HomePage() {
  const { t } = useTranslation();
  return (
    <>
      <RecentReadsCarousel />
      <BookListView
        title={t("home.title")}
        description={t("home.description")}
        emptyMessage={t("home.empty")}
      />
    </>
  );
}
