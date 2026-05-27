import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { BookListView } from "@/components/books/BookListView";
import { DeleteSeriesButton } from "@/components/series/DeleteSeriesButton";
import { useSeries } from "@/hooks/useTaxonomy";

export default function SeriesDetailPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const seriesQuery = useSeries(id);
  const series = seriesQuery.data;

  return (
    <BookListView
      title={series?.name ?? t("books.list.bySeries")}
      baseParams={{ series_id: id }}
      headerActions={series ? <DeleteSeriesButton series={series} /> : null}
    />
  );
}
