import { useState } from "react";
import { Outlet } from "react-router-dom";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Header } from "./Header";
import { Sidebar } from "./Sidebar";

export function AppShell() {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <div className="flex min-h-screen flex-col bg-background text-foreground">
      <Header onOpenSidebar={() => setMobileNavOpen(true)} />

      <div className="flex flex-1">
        {/* desktop sidebar */}
        <aside className="hidden w-60 shrink-0 border-r border-sidebar-border bg-sidebar text-sidebar-foreground md:block">
          <Sidebar />
        </aside>

        {/* mobile sidebar */}
        <Sheet open={mobileNavOpen} onOpenChange={setMobileNavOpen}>
          <SheetContent
            side="left"
            className="w-72 border-r border-sidebar-border bg-sidebar p-0 text-sidebar-foreground"
          >
            <SheetHeader className="px-4 py-3">
              <SheetTitle>ナビゲーション</SheetTitle>
            </SheetHeader>
            <Sidebar onNavigate={() => setMobileNavOpen(false)} />
          </SheetContent>
        </Sheet>

        <main className="min-w-0 flex-1">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
