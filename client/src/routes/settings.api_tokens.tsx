import { useState, type FormEvent } from "react";
import { Copy, Plus, Trash2, Check } from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  useApiTokens,
  useIssueApiToken,
  useRevokeApiToken,
} from "@/hooks/useApiTokens";
import { ApiError } from "@/lib/api";
import type { IssuedApiToken } from "@/types/api";

export default function ApiTokensSettings() {
  const list = useApiTokens();
  const [open, setOpen] = useState(false);
  const [revealed, setRevealed] = useState<IssuedApiToken | null>(null);

  return (
    <section className="mx-auto flex max-w-4xl flex-col gap-6 px-4 py-6">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
            API トークン
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            OPDS リーダーや CLI から認証するための長寿命トークンを発行します。発行時のみ平文が表示されます。
          </p>
        </div>
        <Button onClick={() => setOpen(true)} className="gap-2">
          <Plus className="size-4" aria-hidden />
          発行
        </Button>
      </header>

      {revealed ? (
        <RevealedToken token={revealed} onDismiss={() => setRevealed(null)} />
      ) : null}

      {list.isPending ? (
        <p className="text-sm text-muted-foreground">読み込み中…</p>
      ) : list.isError ? (
        <p className="text-sm text-destructive">取得に失敗しました。</p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>名前</TableHead>
                <TableHead className="w-44 whitespace-nowrap">最終使用</TableHead>
                <TableHead className="w-44 whitespace-nowrap">発行日</TableHead>
                <TableHead className="w-24 text-right">操作</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {list.data!.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-sm text-muted-foreground">
                    トークンはまだ発行されていません。
                  </TableCell>
                </TableRow>
              ) : (
                list.data!.map((token) => (
                  <TokenRow key={token.id} token={token} />
                ))
              )}
            </TableBody>
          </Table>
        </div>
      )}

      <IssueDialog
        open={open}
        onOpenChange={setOpen}
        onIssued={(token) => {
          setRevealed(token);
          setOpen(false);
        }}
      />
    </section>
  );
}

interface TokenRowProps {
  token: { id: number; name: string; last_used_at: string | null; created_at: string };
}

function TokenRow({ token }: TokenRowProps) {
  const revoke = useRevokeApiToken();
  const handleRevoke = () => {
    if (!window.confirm(`「${token.name}」を失効させます。よろしいですか?`)) return;
    revoke.mutate(token.id);
  };
  return (
    <TableRow>
      <TableCell className="font-medium">{token.name}</TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {token.last_used_at ? token.last_used_at.slice(0, 16).replace("T", " ") : "未使用"}
      </TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {token.created_at.slice(0, 10)}
      </TableCell>
      <TableCell className="text-right">
        <Button
          size="sm"
          variant="ghost"
          onClick={handleRevoke}
          disabled={revoke.isPending}
          aria-label="失効"
          className="text-destructive hover:text-destructive"
        >
          <Trash2 className="size-4" />
        </Button>
      </TableCell>
    </TableRow>
  );
}

interface IssueDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onIssued: (token: IssuedApiToken) => void;
}

function IssueDialog({ open, onOpenChange, onIssued }: IssueDialogProps) {
  const issue = useIssueApiToken();
  const [name, setName] = useState("");

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      const token = await issue.mutateAsync({ name });
      setName("");
      onIssued(token);
    } catch {
      // shown below
    }
  };

  return (
    <Dialog open={open} onOpenChange={(o) => { if (!o) issue.reset(); onOpenChange(o); }}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>新しい API トークンを発行</DialogTitle>
          <DialogDescription>用途が分かる名前を付けます。例: 「iPad の OPDS リーダー」</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="token-name">名前</Label>
            <Input
              id="token-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="iPad / OPDS"
            />
          </div>
          {issue.error ? (
            <p className="text-sm text-destructive">{formatError(issue.error)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)} disabled={issue.isPending}>
              キャンセル
            </Button>
            <Button type="submit" disabled={issue.isPending || !name.trim()}>
              {issue.isPending ? "発行中…" : "発行"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function RevealedToken({ token, onDismiss }: { token: IssuedApiToken; onDismiss: () => void }) {
  const [copied, setCopied] = useState(false);
  const opdsUrl = `${window.location.origin}/opds`;

  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      // ignore
    }
  };

  return (
    <div className="grid gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/5 p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold">トークンを発行しました</h2>
          <p className="mt-1 text-xs text-muted-foreground">
            このトークンはこの画面を閉じると再表示できません。OPDS リーダーには Authorization ヘッダ <code className="font-mono">Bearer …</code> または HTTP Basic で渡してください。
          </p>
        </div>
        <Button size="sm" variant="ghost" onClick={onDismiss}>閉じる</Button>
      </div>
      <div className="grid gap-2">
        <Label className="text-xs uppercase tracking-wide text-muted-foreground">トークン</Label>
        <div className="flex items-center gap-2">
          <Input readOnly value={token.token} className="font-mono text-xs" />
          <Button
            size="sm"
            variant="outline"
            onClick={() => copy(token.token)}
            className="gap-1"
            aria-label="トークンをコピー"
          >
            {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
          </Button>
        </div>
        <Label className="mt-2 text-xs uppercase tracking-wide text-muted-foreground">OPDS URL</Label>
        <div className="flex items-center gap-2">
          <Input readOnly value={opdsUrl} className="font-mono text-xs" />
          <Button
            size="sm"
            variant="outline"
            onClick={() => copy(opdsUrl)}
            className="gap-1"
            aria-label="OPDS URL をコピー"
          >
            <Copy className="size-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

function formatError(error: unknown) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return "発行に失敗しました。";
}
