import { useEffect, useMemo } from "react";
import { useWindowVirtualizer } from "@tanstack/react-virtual";
import { useContainerWidth } from "@/hooks/useContainerWidth";
import { useOffsetTop } from "@/hooks/useOffsetTop";
import { BookCard } from "./BookCard";
import type { Book } from "@/types/api";

// gap-3
const GAP = 12;

interface VirtualBookGridProps {
  books: Book[];
  itemSize: number;
  selectionMode: boolean;
  selectedIds: Set<number>;
  onToggleSelect: (id: number) => void;
}

// Window-scrolled row virtualizer: books are chunked into rows matching the
// column count CSS `repeat(auto-fill, minmax(itemSize, 1fr))` would produce,
// and only the visible rows (plus overscan) are mounted.
export function VirtualBookGrid({
  books,
  itemSize,
  selectionMode,
  selectedIds,
  onToggleSelect,
}: VirtualBookGridProps) {
  const [containerRef, width] = useContainerWidth<HTMLDivElement>();
  // Track count of `repeat(auto-fill, minmax(itemSize, 1fr))`: the largest N
  // with N*itemSize + (N-1)*GAP <= width.
  const cols = Math.max(1, Math.floor((width + GAP) / (itemSize + GAP)));
  // Tracks are 1fr, so the rendered column is usually wider than itemSize.
  const colWidth = (width - (cols - 1) * GAP) / cols;

  const rows = useMemo(() => {
    const out: Book[][] = [];
    for (let i = 0; i < books.length; i += cols) out.push(books.slice(i, i + cols));
    return out;
  }, [books, cols]);

  // Keep the scroll offset origin in sync with whatever precedes the grid
  // (BulkActionBar toggling, description, ...).
  const scrollMargin = useOffsetTop(containerRef);

  const virtualizer = useWindowVirtualizer({
    count: rows.length,
    // 2:3 cover + text block/padding + row gap; measureElement corrects it.
    estimateSize: () => colWidth * 1.5 + 66 + GAP,
    overscan: 4,
    scrollMargin,
  });

  // Row contents shuffle when the column count changes; drop measurements
  // cached for unmounted rows.
  useEffect(() => {
    virtualizer.measure();
  }, [cols, itemSize, virtualizer]);

  return (
    <div
      ref={containerRef}
      className="relative w-full"
      style={{ height: virtualizer.getTotalSize() }}
    >
      {width > 0 &&
        virtualizer.getVirtualItems().map((vRow) => (
          <div
            key={vRow.key}
            data-index={vRow.index}
            ref={virtualizer.measureElement}
            // Row spacing lives in pb-3 because `gap` cannot reach absolutely
            // positioned siblings; measureElement measures border-box so the
            // padding is part of the row height.
            className="absolute left-0 top-0 grid w-full gap-3 pb-3"
            style={{
              gridTemplateColumns: `repeat(${cols}, minmax(0, 1fr))`,
              transform: `translateY(${vRow.start - virtualizer.options.scrollMargin}px)`,
            }}
          >
            {rows[vRow.index].map((book) => (
              <BookCard
                key={book.id}
                book={book}
                selectable={selectionMode}
                selected={selectedIds.has(book.id)}
                onToggleSelect={onToggleSelect}
              />
            ))}
          </div>
        ))}
    </div>
  );
}
