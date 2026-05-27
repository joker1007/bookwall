import type { ReactNode } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { useAuthStore } from "@/stores/authStore";

interface Props {
  children: ReactNode;
}

export function ProtectedRoute({ children }: Props) {
  const { t } = useTranslation();
  const status = useAuthStore((s) => s.status);
  const location = useLocation();

  if (status === "idle" || status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center text-muted-foreground">
        {t("common.loading")}
      </div>
    );
  }

  if (status === "unauthenticated") {
    const search = new URLSearchParams({ from: location.pathname }).toString();
    return <Navigate to={`/login?${search}`} replace />;
  }

  return <>{children}</>;
}
