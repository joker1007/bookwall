import { useAuthStore } from "@/stores/authStore";

export default function HomePage() {
  const user = useAuthStore((s) => s.user);

  return (
    <section className="mx-auto flex max-w-5xl flex-col gap-6 px-4 py-8">
      <header className="flex flex-col gap-2">
        <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">ホーム</h1>
        <p className="text-sm text-muted-foreground">
          ようこそ <span className="font-mono">{user?.email_address}</span> さん。
        </p>
      </header>

      <section className="rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          最近追加されたシリーズ
        </h2>
        <p className="mt-2 text-sm text-muted-foreground">
          書籍一覧と最近追加されたシリーズは次の UI Phase で追加されます。
        </p>
      </section>
    </section>
  );
}
