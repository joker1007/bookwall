import { useState, type FormEvent } from "react";
import { Trans, useTranslation } from "react-i18next";
import { Copy, Eye, Plus, Trash2, Check } from "lucide-react";
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
import type { ApiToken, IssuedApiToken } from "@/types/api";

type RevealMode = "issued" | "show";

export default function ApiTokensSettings() {
  const { t } = useTranslation();
  const list = useApiTokens();
  const [open, setOpen] = useState(false);
  const [revealed, setRevealed] = useState<ApiToken | null>(null);
  const [revealMode, setRevealMode] = useState<RevealMode>("show");

  const showToken = (token: ApiToken, justIssued = false) => {
    setRevealMode(justIssued ? "issued" : "show");
    setRevealed(token);
  };

  return (
    <section className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-6">
      <header className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight md:text-3xl">
            {t("settings.apiTokens.title")}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {t("settings.apiTokens.description")}
          </p>
        </div>
        <Button onClick={() => setOpen(true)} className="gap-2">
          <Plus className="size-4" aria-hidden />
          {t("settings.apiTokens.issue")}
        </Button>
      </header>

      {revealed ? (
        <RevealedToken
          token={revealed}
          mode={revealMode}
          onDismiss={() => setRevealed(null)}
        />
      ) : null}

      {list.isPending ? (
        <p className="text-sm text-muted-foreground">{t("common.loading")}</p>
      ) : list.isError ? (
        <p className="text-sm text-destructive">{t("common.fetchFailed")}</p>
      ) : (
        <div className="overflow-hidden rounded-lg border border-border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t("settings.apiTokens.columns.name")}</TableHead>
                <TableHead className="w-44 whitespace-nowrap">
                  {t("settings.apiTokens.columns.lastUsedAt")}
                </TableHead>
                <TableHead className="w-44 whitespace-nowrap">
                  {t("settings.apiTokens.columns.createdAt")}
                </TableHead>
                <TableHead className="w-32 text-right">
                  {t("settings.apiTokens.columns.actions")}
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {list.data!.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="text-center text-sm text-muted-foreground">
                    {t("settings.apiTokens.empty")}
                  </TableCell>
                </TableRow>
              ) : (
                list.data!.map((token) => (
                  <TokenRow
                    key={token.id}
                    token={token}
                    onShow={() => showToken(token)}
                  />
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
          showToken(token, true);
          setOpen(false);
        }}
      />
    </section>
  );
}

interface TokenRowProps {
  token: ApiToken;
  onShow: () => void;
}

function TokenRow({ token, onShow }: TokenRowProps) {
  const { t } = useTranslation();
  const revoke = useRevokeApiToken();
  const handleRevoke = () => {
    if (!window.confirm(t("settings.apiTokens.revokeConfirm", { name: token.name }))) return;
    revoke.mutate(token.id);
  };
  return (
    <TableRow>
      <TableCell className="font-medium">{token.name}</TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {token.last_used_at
          ? token.last_used_at.slice(0, 16).replace("T", " ")
          : t("common.noUnusedAt")}
      </TableCell>
      <TableCell className="text-xs text-muted-foreground">
        {token.created_at.slice(0, 10)}
      </TableCell>
      <TableCell className="text-right">
        <div className="flex justify-end gap-1">
          <Button
            size="sm"
            variant="ghost"
            onClick={onShow}
            aria-label={t("settings.apiTokens.show")}
            title={t("settings.apiTokens.show")}
          >
            <Eye className="size-4" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            onClick={handleRevoke}
            disabled={revoke.isPending}
            aria-label={t("settings.apiTokens.revoke")}
            className="text-destructive hover:text-destructive"
          >
            <Trash2 className="size-4" />
          </Button>
        </div>
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
  const { t } = useTranslation();
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
          <DialogTitle>{t("settings.apiTokens.dialog.title")}</DialogTitle>
          <DialogDescription>{t("settings.apiTokens.dialog.description")}</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <div className="grid gap-2">
            <Label htmlFor="token-name">{t("settings.apiTokens.dialog.name")}</Label>
            <Input
              id="token-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder={t("settings.apiTokens.dialog.namePlaceholder")}
            />
          </div>
          {issue.error ? (
            <p className="text-sm text-destructive">{formatError(issue.error, t)}</p>
          ) : null}
          <DialogFooter className="gap-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={issue.isPending}
            >
              {t("common.cancel")}
            </Button>
            <Button type="submit" disabled={issue.isPending || !name.trim()}>
              {issue.isPending ? t("common.issuing") : t("settings.apiTokens.issue")}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

interface RevealedTokenProps {
  token: ApiToken;
  mode: RevealMode;
  onDismiss: () => void;
}

function RevealedToken({ token, mode, onDismiss }: RevealedTokenProps) {
  const { t } = useTranslation();
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

  const heading =
    mode === "issued"
      ? t("settings.apiTokens.reveal.issuedHeading")
      : t("settings.apiTokens.reveal.showHeading");

  return (
    <div className="grid gap-3 rounded-lg border border-emerald-500/40 bg-emerald-500/5 p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold">{heading}</h2>
          <p className="mt-1 text-xs text-muted-foreground">
            <Trans
              i18nKey="settings.apiTokens.reveal.description"
              components={{ code: <code className="font-mono" /> }}
            />
          </p>
        </div>
        <Button size="sm" variant="ghost" onClick={onDismiss}>
          {t("common.close")}
        </Button>
      </div>
      <div className="grid gap-2">
        <Label className="text-xs uppercase tracking-wide text-muted-foreground">
          {t("settings.apiTokens.reveal.tokenLabel")}
        </Label>
        <div className="flex items-center gap-2">
          <Input readOnly value={token.token} className="font-mono text-xs" />
          <Button
            size="sm"
            variant="outline"
            onClick={() => copy(token.token)}
            className="gap-1"
            aria-label={t("settings.apiTokens.reveal.tokenCopy")}
          >
            {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
          </Button>
        </div>
        <Label className="mt-2 text-xs uppercase tracking-wide text-muted-foreground">
          {t("settings.apiTokens.reveal.opdsLabel")}
        </Label>
        <div className="flex items-center gap-2">
          <Input readOnly value={opdsUrl} className="font-mono text-xs" />
          <Button
            size="sm"
            variant="outline"
            onClick={() => copy(opdsUrl)}
            className="gap-1"
            aria-label={t("settings.apiTokens.reveal.opdsCopy")}
          >
            <Copy className="size-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}

function formatError(error: unknown, t: (key: string) => string) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return t("settings.apiTokens.issueFailed");
}
