import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "@/lib/queryClient";
import RootLayout from "@/routes/_layout";
import HomePage from "@/routes/home";
import LoginPage from "@/routes/login";
import SignupPage from "@/routes/signup";
import { Placeholder } from "@/components/Placeholder";
import { SessionBootstrap } from "@/components/SessionBootstrap";
import { ProtectedRoute } from "@/components/ProtectedRoute";

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename="/ui">
        <SessionBootstrap />
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/signup" element={<SignupPage />} />
          <Route
            element={
              <ProtectedRoute>
                <RootLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<HomePage />} />
            <Route path="libraries" element={<Placeholder title="ライブラリ" />} />
            <Route path="libraries/:id" element={<Placeholder title="ライブラリ詳細" />} />
            <Route path="series" element={<Placeholder title="シリーズ" />} />
            <Route path="series/:id" element={<Placeholder title="シリーズ詳細" />} />
            <Route path="authors" element={<Placeholder title="著者" />} />
            <Route path="authors/:id" element={<Placeholder title="著者詳細" />} />
            <Route path="tags" element={<Placeholder title="タグ" />} />
            <Route path="tags/:id" element={<Placeholder title="タグ詳細" />} />
            <Route path="favorites" element={<Placeholder title="お気に入り" />} />
            <Route path="search" element={<Placeholder title="検索結果" />} />
            <Route path="books/:id" element={<Placeholder title="書籍詳細" />} />
            <Route
              path="settings/libraries"
              element={<Placeholder title="設定 — ライブラリ" />}
            />
            <Route
              path="settings/api_tokens"
              element={<Placeholder title="設定 — API トークン" />}
            />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
