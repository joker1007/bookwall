import { useState, type FormEvent } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useAuthStore } from "@/stores/authStore";
import { useRegister } from "@/hooks/useAuth";
import { ApiError } from "@/lib/api";

export default function SignupPage() {
  const status = useAuthStore((s) => s.status);
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const register = useRegister();

  if (status === "authenticated") return <Navigate to="/" replace />;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (password !== confirm) {
      register.reset();
      return;
    }
    try {
      await register.mutateAsync({
        email_address: email,
        password,
        password_confirmation: confirm,
      });
      navigate("/", { replace: true });
    } catch {
      // error shown below
    }
  };

  const mismatch = password.length > 0 && confirm.length > 0 && password !== confirm;

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4">
      <Card>
        <CardHeader>
          <CardTitle>Bookwall にサインアップ</CardTitle>
          <CardDescription>新しいアカウントを作成します。</CardDescription>
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
              <Label htmlFor="password">パスワード (8 文字以上)</Label>
              <Input
                id="password"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="password_confirmation">パスワード (確認)</Label>
              <Input
                id="password_confirmation"
                type="password"
                autoComplete="new-password"
                required
                minLength={8}
                value={confirm}
                onChange={(e) => setConfirm(e.target.value)}
              />
              {mismatch ? (
                <p className="text-xs text-destructive">パスワードが一致しません。</p>
              ) : null}
            </div>
            {register.error ? (
              <p className="text-sm text-destructive">{formatSignupError(register.error)}</p>
            ) : null}
            <Button
              type="submit"
              disabled={register.isPending || mismatch}
              className="min-h-11"
            >
              {register.isPending ? "登録中…" : "アカウントを作成"}
            </Button>
            <p className="text-center text-sm text-muted-foreground">
              既にアカウントをお持ちの方は{" "}
              <Link to="/login" className="text-foreground underline-offset-4 hover:underline">
                ログイン
              </Link>
            </p>
          </form>
        </CardContent>
      </Card>
    </main>
  );
}

function formatSignupError(error: unknown) {
  if (error instanceof ApiError) {
    const body = error.body as { errors?: string[] } | undefined;
    if (body?.errors?.length) return body.errors.join(" / ");
  }
  return "登録に失敗しました。入力内容を確認してください。";
}
