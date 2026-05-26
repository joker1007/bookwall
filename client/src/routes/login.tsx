import { useState, type FormEvent } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuthStore } from "@/stores/authStore";
import { useLogin } from "@/hooks/useAuth";
import { ApiError } from "@/lib/api";

export default function LoginPage() {
  const status = useAuthStore((s) => s.status);
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const login = useLogin();

  if (status === "authenticated") {
    return <Navigate to={resolveRedirect(location.search)} replace />;
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    try {
      await login.mutateAsync({ email_address: email, password });
      navigate(resolveRedirect(location.search), { replace: true });
    } catch {
      // error rendered below
    }
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4">
      <Card>
        <CardHeader>
          <CardTitle>Bookwall にログイン</CardTitle>
          <CardDescription>
            登録済みのメールアドレスとパスワードでログインします。
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="email">メールアドレス</Label>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="password">パスワード</Label>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {login.error ? (
              <p className="text-sm text-destructive">{formatLoginError(login.error)}</p>
            ) : null}
            <Button type="submit" disabled={login.isPending} className="min-h-11">
              {login.isPending ? "ログイン中…" : "ログイン"}
            </Button>
            <p className="text-center text-sm text-muted-foreground">
              アカウント未登録の方は{" "}
              <Link to="/signup" className="text-foreground underline-offset-4 hover:underline">
                サインアップ
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}

function resolveRedirect(search: string) {
  const from = new URLSearchParams(search).get("from");
  if (!from || !from.startsWith("/")) return "/";
  return from;
}

function formatLoginError(error: unknown) {
  if (error instanceof ApiError && error.status === 401) {
    return "メールアドレスまたはパスワードが正しくありません。";
  }
  return "ログインに失敗しました。時間をおいて再度お試しください。";
}
