import { NavLink } from "react-router-dom";
import {
  Home,
  Library as LibraryIcon,
  Layers,
  Users,
  Tag as TagIcon,
  Heart,
  Settings,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
  end?: boolean;
}

const NAV: NavItem[] = [
  { to: "/", label: "ホーム", icon: Home, end: true },
  { to: "/libraries", label: "ライブラリ", icon: LibraryIcon },
  { to: "/series", label: "シリーズ", icon: Layers },
  { to: "/authors", label: "著者", icon: Users },
  { to: "/tags", label: "タグ", icon: TagIcon },
  { to: "/favorites", label: "お気に入り", icon: Heart },
  { to: "/settings/libraries", label: "設定", icon: Settings },
];

interface SidebarProps {
  onNavigate?: () => void;
}

export function Sidebar({ onNavigate }: SidebarProps) {
  return (
    <nav className="flex h-full flex-col gap-1 px-3 py-4">
      <div className="px-2 pb-3">
        <p className="text-xs font-semibold uppercase tracking-wide text-sidebar-foreground/60">
          Bookwall
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
              isActive && "bg-sidebar-accent text-sidebar-accent-foreground"
            )
          }
        >
          <item.icon className="size-4 shrink-0" aria-hidden />
          <span>{item.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}
