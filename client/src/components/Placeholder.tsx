import { useTranslation } from "react-i18next";

interface PlaceholderProps {
  title: string;
  description?: string;
}

export function Placeholder({ title, description }: PlaceholderProps) {
  const { t } = useTranslation();
  return (
    <section className="mx-auto flex max-w-5xl flex-col gap-3 px-4 py-12">
      <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
      <p className="text-sm text-muted-foreground">
        {description ?? t("placeholder.description")}
      </p>
    </section>
  );
}
