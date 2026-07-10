import { NavLink } from "react-router-dom";
import { useTranslation } from "react-i18next";
import {
  Home,
  Library as LibraryIcon,
  Layers,
  Users,
  Tag as TagIcon,
  Bookmark,
  Heart,
  Settings,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLibraries } from "@/hooks/useLibraries";

interface NavItem {
  to: string;
  labelKey: string;
  icon: LucideIcon;
  end?: boolean;
}

const NAV: NavItem[] = [
  { to: "/", labelKey: "nav.home", icon: Home, end: true },
  { to: "/series", labelKey: "nav.series", icon: Layers },
  { to: "/authors", labelKey: "nav.authors", icon: Users },
  { to: "/tags", labelKey: "nav.tags", icon: TagIcon },
  { to: "/collections", labelKey: "nav.collections", icon: Bookmark },
  { to: "/favorites", labelKey: "nav.favorites", icon: Heart },
  { to: "/settings/libraries", labelKey: "nav.settings", icon: Settings },
];

interface SidebarProps {
  onNavigate?: () => void;
}

export function Sidebar({ onNavigate }: SidebarProps) {
  const { t } = useTranslation();
  const libraries = useLibraries();
  const items = libraries.data?.libraries ?? [];

  return (
    <nav className="flex min-h-full flex-col gap-1 px-3 py-4">
      <div className="px-2 pb-3">
        <p className="text-xs font-semibold uppercase tracking-wide text-sidebar-foreground/60">
          {t("app.title")}
        </p>
      </div>
      {NAV.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          end={item.end}
          onClick={onNavigate}
          className={({ isActive }) =>
            cn(
              "flex min-h-11 items-center gap-3 rounded-md px-3 text-sm font-medium transition-colors",
              "text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
              isActive && "bg-sidebar-accent text-sidebar-accent-foreground",
            )
          }
        >
          <item.icon className="size-4 shrink-0" aria-hidden />
          <span>{t(item.labelKey)}</span>
        </NavLink>
      ))}

      <div className="mt-4 px-2 pb-1">
        <p className="text-xs font-semibold uppercase tracking-wide text-sidebar-foreground/60">
          {t("nav.myLibraries")}
        </p>
      </div>
      {libraries.isPending ? (
        <p className="px-3 text-xs text-sidebar-foreground/50">
          {t("common.loading")}
        </p>
      ) : items.length === 0 ? (
        <p className="px-3 text-xs text-sidebar-foreground/50">
          {t("nav.noLibraries")}
        </p>
      ) : (
        items.map((library) => (
          <NavLink
            key={library.id}
            to={`/libraries/${library.id}`}
            onClick={onNavigate}
            title={library.path}
            className={({ isActive }) =>
              cn(
                "flex min-h-11 items-center gap-3 rounded-md px-3 text-sm transition-colors",
                "text-sidebar-foreground hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                isActive && "bg-sidebar-accent text-sidebar-accent-foreground",
              )
            }
          >
            <LibraryIcon className="size-4 shrink-0" aria-hidden />
            <span className="truncate">{library.name}</span>
          </NavLink>
        ))
      )}
    </nav>
  );
}
