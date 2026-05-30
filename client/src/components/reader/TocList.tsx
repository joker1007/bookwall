export interface TocEntry {
  label: string;
  subitems?: TocEntry[];
}

interface TocListProps<T extends TocEntry> {
  items: T[];
  onSelect: (item: T) => void;
  depth?: number;
  disabled?: (item: T) => boolean;
}

export function TocList<T extends TocEntry>({
  items,
  onSelect,
  depth = 0,
  disabled,
}: TocListProps<T>) {
  return (
    <ul className="flex flex-col gap-0.5">
      {items.map((item, i) => (
        <li key={`${depth}-${i}`}>
          <button
            type="button"
            onClick={() => onSelect(item)}
            disabled={disabled?.(item) ?? false}
            className="block w-full rounded px-2 py-1.5 text-left text-sm hover:bg-accent hover:text-accent-foreground disabled:cursor-default disabled:opacity-40 disabled:hover:bg-transparent"
            style={{ paddingInlineStart: `${depth * 12 + 8}px` }}
          >
            {item.label}
          </button>
          {item.subitems?.length ? (
            <TocList
              items={item.subitems as T[]}
              onSelect={onSelect}
              depth={depth + 1}
              disabled={disabled}
            />
          ) : null}
        </li>
      ))}
    </ul>
  );
}
