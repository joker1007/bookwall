interface PlaceholderProps {
  title: string;
  description?: string;
}

export function Placeholder({ title, description }: PlaceholderProps) {
  return (
    <section className="mx-auto flex max-w-5xl flex-col gap-3 px-4 py-12">
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      {description ? (
        <p className="text-sm text-muted-foreground">{description}</p>
      ) : (
        <p className="text-sm text-muted-foreground">
          このページは次の UI Phase で実装されます。
        </p>
      )}
    </section>
  );
}
