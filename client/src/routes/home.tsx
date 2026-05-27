import { RecentReadsCarousel } from "@/components/books/RecentReadsCarousel";
import { FavoritesCarousel } from "@/components/books/FavoritesCarousel";

export default function HomePage() {
  return (
    <>
      <RecentReadsCarousel />
      <FavoritesCarousel />
    </>
  );
}
