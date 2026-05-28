import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { QueryClientProvider } from "@tanstack/react-query";
import { queryClient } from "@/lib/queryClient";
import RootLayout from "@/routes/_layout";
import HomePage from "@/routes/home";
import LoginPage from "@/routes/login";
import SignupPage from "@/routes/signup";
import LibraryDetailPage from "@/routes/libraries.detail";
import SeriesIndexPage from "@/routes/series";
import SeriesDetailPage from "@/routes/series.detail";
import AuthorsIndexPage from "@/routes/authors";
import AuthorDetailPage from "@/routes/authors.detail";
import TagsIndexPage from "@/routes/tags";
import TagDetailPage from "@/routes/tags.detail";
import CollectionsIndexPage from "@/routes/collections";
import CollectionDetailPage from "@/routes/collections.detail";
import FavoritesPage from "@/routes/favorites";
import BookDetailPage from "@/routes/books.detail";
import ReaderPage from "@/routes/books.read";
import SearchPage from "@/routes/search";
import LibrariesSettings from "@/routes/settings.libraries";
import ApiTokensSettings from "@/routes/settings.api_tokens";
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
          {/* Reader is fullscreen — outside the AppShell layout so Sidebar
              and Header don't fight with the immersive view. */}
          <Route
            path="/books/:id/read"
            element={
              <ProtectedRoute>
                <ReaderPage />
              </ProtectedRoute>
            }
          />
          <Route
            element={
              <ProtectedRoute>
                <RootLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<HomePage />} />
            {/* Libraries are picked directly from the sidebar; the bare
                /libraries URL has nothing to show. */}
            <Route path="libraries" element={<Navigate to="/" replace />} />
            <Route path="libraries/:id" element={<LibraryDetailPage />} />
            <Route path="series" element={<SeriesIndexPage />} />
            <Route path="series/:id" element={<SeriesDetailPage />} />
            <Route path="authors" element={<AuthorsIndexPage />} />
            <Route path="authors/:id" element={<AuthorDetailPage />} />
            <Route path="tags" element={<TagsIndexPage />} />
            <Route path="tags/:id" element={<TagDetailPage />} />
            <Route path="collections" element={<CollectionsIndexPage />} />
            <Route path="collections/:id" element={<CollectionDetailPage />} />
            <Route path="favorites" element={<FavoritesPage />} />
            <Route path="search" element={<SearchPage />} />
            <Route path="books/:id" element={<BookDetailPage />} />
            <Route path="settings/libraries" element={<LibrariesSettings />} />
            <Route path="settings/api_tokens" element={<ApiTokensSettings />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
