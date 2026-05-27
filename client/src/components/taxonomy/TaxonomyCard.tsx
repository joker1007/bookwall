import { Link } from "react-router-dom";
import type { ReactNode } from "react";
import { ImageOff } from "lucide-react";

interface TaxonomyCardProps {
  to: string;
  name: string;
  thumbUrl: string | null;
  meta?: ReactNode;
}

export function TaxonomyCard({ to, name, thumbUrl, meta }: TaxonomyCardProps) {
  return (
    <Link
      to={to}
      className="group flex flex-col gap-2 rounded-lg p-2 transition-colors hover:bg-accent"
    >
      <div className="aspect-[2/3] w-full overflow-hidden rounded-md bg-muted">
        {thumbUrl ? (
          <img
            src={thumbUrl}
            alt={name}
            className="size-full object-cover transition-transform group-hover:scale-[1.02]"
            loading="lazy"
          />
        ) : (
          <div className="flex size-full items-center justify-center text-muted-foreground">
            <ImageOff className="size-8" aria-hidden />
          </div>
        )}
      </div>
      <div className="flex flex-col gap-0.5">
        <p className="line-clamp-2 text-sm font-medium leading-tight">{name}</p>
        {meta ? (
          <p className="text-xs text-muted-foreground">{meta}</p>
        ) : null}
      </div>
    </Link>
  );
}
