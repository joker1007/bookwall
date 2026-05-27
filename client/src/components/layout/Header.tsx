import { useState, type FormEvent } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Menu, Search, LogOut, User as UserIcon, Check, Languages } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useAuthStore } from "@/stores/authStore";
import { useLogout } from "@/hooks/useAuth";
import { SUPPORTED_LANGUAGES, type LanguageCode } from "@/lib/i18n";

interface HeaderProps {
  onOpenSidebar: () => void;
}

export function Header({ onOpenSidebar }: HeaderProps) {
  const { t, i18n } = useTranslation();
  const user = useAuthStore((s) => s.user);
  const logout = useLogout();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [q, setQ] = useState(params.get("q") ?? "");

  const handleSearch = (e: FormEvent) => {
    e.preventDefault();
    const trimmed = q.trim();
    if (!trimmed) return;
    navigate(`/search?q=${encodeURIComponent(trimmed)}`);
  };

  const currentLang = (i18n.resolvedLanguage ?? i18n.language ?? "ja") as LanguageCode;

  return (
    <header className="sticky top-0 z-30 flex h-14 items-center gap-2 border-b border-border bg-background/80 px-3 backdrop-blur md:px-4">
      <Button
        variant="ghost"
        size="icon"
        className="md:hidden"
        aria-label={t("app.openNav")}
        onClick={onOpenSidebar}
      >
        <Menu className="size-5" />
      </Button>

      <form onSubmit={handleSearch} className="relative flex flex-1 items-center">
        <Search
          className="pointer-events-none absolute left-3 size-4 text-muted-foreground"
          aria-hidden
        />
        <Input
          type="search"
          inputMode="search"
          aria-label={t("app.search")}
          placeholder={t("app.searchPlaceholder")}
          value={q}
          onChange={(e) => setQ(e.target.value)}
          className="h-10 pl-9"
        />
      </form>

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" aria-label={t("app.userMenu")}>
            <UserIcon className="size-5" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-56">
          <DropdownMenuLabel className="truncate">{user?.email_address}</DropdownMenuLabel>
          <DropdownMenuSeparator />
          <DropdownMenuItem onSelect={() => navigate("/settings/api_tokens")}>
            {t("nav.settingsApiTokens")}
          </DropdownMenuItem>
          <DropdownMenuItem onSelect={() => navigate("/settings/libraries")}>
            {t("nav.settingsLibraries")}
          </DropdownMenuItem>
          {SUPPORTED_LANGUAGES.map((lang) => (
            <DropdownMenuItem
              key={lang}
              onSelect={() => i18n.changeLanguage(lang)}
            >
              {currentLang === lang ? (
                <Check className="mr-2 size-4" />
              ) : (
                <Languages className="mr-2 size-4" />
              )}
              {t(`language.${lang}`)}
            </DropdownMenuItem>
          ))}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            onSelect={() => logout.mutate()}
            disabled={logout.isPending}
          >
            <LogOut className="mr-2 size-4" />
            {t("nav.logout")}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </header>
  );
}
