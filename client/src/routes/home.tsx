import { useTranslation } from "react-i18next";
import { RecentReadsCarousel } from "@/components/books/RecentReadsCarousel";
import { FavoritesCarousel } from "@/components/books/FavoritesCarousel";

export default function HomePage() {
  const { t } = useTranslation();
  return (
    <>
      <header className="mx-auto w-full max-w-[1920px] px-4 pt-6">
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
          {t("home.title")}
        </h1>
      </header>
      <RecentReadsCarousel />
      <FavoritesCarousel />
    </>
  );
}
