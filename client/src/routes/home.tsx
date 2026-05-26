import { Button } from "@/components/ui/button";
import { useAuthStore } from "@/stores/authStore";
import { useLogout } from "@/hooks/useAuth";
import { useUiStore } from "@/stores/uiStore";

export default function HomePage() {
  const user = useAuthStore((s) => s.user);
  const logout = useLogout();
  const displayMode = useUiStore((s) => s.displayMode);
  const setDisplayMode = useUiStore((s) => s.setDisplayMode);

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col gap-6 px-4 py-12">
      <header className="flex items-start justify-between gap-4">
        <div className="flex flex-col gap-2">
          <h1 className="text-3xl font-semibold tracking-tight">Bookwall</h1>
          <p className="text-sm text-muted-foreground">
            ログイン中: <span className="font-mono">{user?.email_address}</span>
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => logout.mutate()}
          disabled={logout.isPending}
        >
          {logout.isPending ? "ログアウト中…" : "ログアウト"}
        </Button>
      </header>

      <section className="grid gap-3 rounded-lg border border-border bg-card p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          表示モード (persist 検証)
        </h2>
        <div className="flex gap-2">
          {(["grid", "list"] as const).map((mode) => (
            <Button
              key={mode}
              variant={displayMode === mode ? "default" : "outline"}
              onClick={() => setDisplayMode(mode)}
              className="min-h-11"
            >
              {mode}
            </Button>
          ))}
        </div>
        <p className="text-xs text-muted-foreground">
          現在のモード: <span className="font-mono">{displayMode}</span> — reload しても維持されます (localStorage)。
        </p>
      </section>

      <p className="text-sm text-muted-foreground">
        書籍一覧や検索は次の UI Phase で追加されます。
      </p>
    </main>
  );
}
