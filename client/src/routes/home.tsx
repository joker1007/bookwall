import { useQuery } from "@tanstack/react-query";
import { useUiStore } from "@/stores/uiStore";
import { api } from "@/lib/api";

export default function HomePage() {
  const displayMode = useUiStore((s) => s.displayMode);
  const setDisplayMode = useUiStore((s) => s.setDisplayMode);

  // Smoke-check the server is reachable via the Vite proxy. /up returns
  // 200 with an HTML body from Rails, so we treat any 2xx as healthy.
  const health = useQuery({
    queryKey: ["health"],
    queryFn: async () => {
      try {
        await api("/up");
        return "ok" as const;
      } catch {
        return "error" as const;
      }
    },
  });

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 px-4 py-12">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl font-semibold tracking-tight">Bookwall</h1>
        <p className="text-sm text-muted-foreground">
          電子書籍管理サーバの UI。スキャフォールディング段階のプレビューです。
        </p>
      </header>

      <section className="grid gap-3 rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          システム状態
        </h2>
        <p className="text-sm">
          server health:{" "}
          <span
            className={
              health.data === "ok"
                ? "font-mono text-emerald-400"
                : health.data === "error"
                  ? "font-mono text-destructive"
                  : "font-mono text-muted-foreground"
            }
          >
            {health.isPending ? "loading…" : (health.data ?? "unknown")}
          </span>
        </p>
      </section>

      <section className="grid gap-3 rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          表示モード (persist 検証)
        </h2>
        <div className="flex gap-2">
          {(["grid", "list"] as const).map((mode) => (
            <button
              key={mode}
              type="button"
              onClick={() => setDisplayMode(mode)}
              className={
                "min-h-11 rounded-md border px-4 text-sm font-medium transition-colors " +
                (displayMode === mode
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border bg-background text-foreground hover:bg-accent")
              }
            >
              {mode}
            </button>
          ))}
        </div>
        <p className="text-xs text-muted-foreground">
          現在のモード: <span className="font-mono">{displayMode}</span> — reload しても維持されます (localStorage)。
        </p>
      </section>
    </main>
  );
}
