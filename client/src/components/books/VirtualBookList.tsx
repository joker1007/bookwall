import { useRef } from "react";
import { useWindowVirtualizer } from "@tanstack/react-virtual";
import { useOffsetTop } from "@/hooks/useOffsetTop";
import { BookRow } from "./BookRow";
import type { Book } from "@/types/api";

interface VirtualBookListProps {
  books: Book[];
  selectionMode: boolean;
  selectedIds: Set<number>;
  onToggleSelect: (id: number) => void;
}

// Window-scrolled virtualizer for the list display: one book per virtual row.
export function VirtualBookList({
  books,
  selectionMode,
  selectedIds,
  onToggleSelect,
}: VirtualBookListProps) {
  const containerRef = useRef<HTMLUListElement | null>(null);
  const scrollMargin = useOffsetTop(containerRef);

  const virtualizer = useWindowVirtualizer({
    count: books.length,
    estimateSize: () => 120,
    overscan: 8,
    scrollMargin,
  });

  return (
    <ul
      ref={containerRef}
      className="relative w-full"
      style={{ height: virtualizer.getTotalSize() }}
    >
      {virtualizer.getVirtualItems().map((item) => {
        const book = books[item.index];
        return (
          <li
            key={item.key}
            data-index={item.index}
            ref={virtualizer.measureElement}
            // gap-1 equivalent baked into pb-1 (see VirtualBookGrid).
            className="absolute left-0 top-0 w-full pb-1"
            style={{
              transform: `translateY(${item.start - virtualizer.options.scrollMargin}px)`,
            }}
          >
            <BookRow
              book={book}
              selectable={selectionMode}
              selected={selectedIds.has(book.id)}
              onToggleSelect={onToggleSelect}
            />
          </li>
        );
      })}
    </ul>
  );
}
