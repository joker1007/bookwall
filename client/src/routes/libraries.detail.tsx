import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { BookListView } from "@/components/books/BookListView";
import type { Library } from "@/types/api";

export default function LibraryDetailPage() {
  const { id } = useParams();
  const library = useQuery<Library>({
    queryKey: ["library", id],
    enabled: !!id,
    queryFn: () => api<Library>(`/api/libraries/${id}`),
  });

  return (
    <BookListView
      title={library.data?.name ?? "ライブラリ"}
      description={library.data?.path}
      baseParams={{ library_id: id }}
    />
  );
}
