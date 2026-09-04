# Bookwall client

[日本語版 README はこちら / Japanese README](./README-ja.md)

## Tech stack

- **Vite 8** + **React 19** + **TypeScript** (with `verbatimModuleSyntax` enabled)
- **Tailwind CSS v4** (`@tailwindcss/vite`) + **shadcn/ui** (Radix + Tailwind)
- **React Router v7** (`<BrowserRouter basename="/ui">`)
- **TanStack Query v5** — server state (books / session / tokens / reading progress)
- **Zustand** — client state (`displayMode` and `sortOrder` are persisted to localStorage via `persist`)
- **react-i18next** — JA/EN i18n (`src/locales/{en,ja}.json`)
- **foliate-js** — EPUB renderer (`<foliate-view>` custom element / iframe + shadow DOM). Local fixes live in `patches/` and are applied by **patch-package** on `npm install`
- **PDF.js** — PDF renderer
- **lucide-react** — icons

## Development

Normally you just run `bin/dev` on the server side; foreman starts both Rails (Falcon) and Vite, so you don't need to touch this directory directly. See the root [README](../README.md#3-start-the-dev-servers-together) for details.

To run the client alone:

```sh
npm install
npm run dev          # Vite (http://localhost:5173)
```

## Build

Development bundle:

```sh
npm run build
# → Emits index.html + assets into client/dist/
```

When bundling alongside the server, switch the output directory to server/public/ui:

```sh
npm run build -- --outDir ../server/public/ui --emptyOutDir
```

See [Dockerfile](../Dockerfile).

## Directory layout

```
client/
├── index.html                  # <html lang="ja" class="dark">
├── vite.config.ts              # base="/ui/" + dev proxy + path alias @/
├── tsconfig.app.json           # paths: { "@/*": ["./src/*"] }
├── components.json             # shadcn/ui config
├── patches/                    # patch-package patches (foliate-js)
├── tests/e2e/                  # Playwright e2e (see playwright.config.ts)
└── src/
    ├── main.tsx
    ├── App.tsx                 # Router + QueryClientProvider + SessionBootstrap
    ├── index.css               # Tailwind v4 + shadcn CSS variables
    ├── routes/                 # 1 file = 1 route
    │   ├── _layout.tsx         #   Thin wrapper that only mounts AppShell
    │   ├── home.tsx            #   "/" Recently-read / favorites carousels + recently-added books
    │   ├── login.tsx           #   "/login" public
    │   ├── signup.tsx          #   "/signup" public (redirects to /login while registration is closed)
    │   ├── books.detail.tsx    #   "/books/:id"
    │   ├── books.read.tsx      #   "/books/:id/read" CBZ / PDF / image_dir reader (EPUB is embedded)
    │   ├── libraries.detail.tsx
    │   ├── series.detail.tsx
    │   ├── authors.detail.tsx
    │   ├── tags.detail.tsx
    │   ├── collections.detail.tsx
    │   ├── series.tsx authors.tsx tags.tsx collections.tsx
    │   ├── favorites.tsx
    │   ├── search.tsx
    │   ├── settings.libraries.tsx
    │   └── settings.api_tokens.tsx
    ├── components/
    │   ├── ui/                 # shadcn-generated (button, card, dialog, table, …)
    │   ├── layout/             # AppShell, Header, Sidebar
    │   ├── books/              # BookListView, BookCard, BookRow, BookCover (with progress-bar overlay), BookEditDialog, BookActions, BulkActionBar, CollectionAssignDialog, RecentReadsCarousel, FavoritesCarousel
    │   ├── reader/             # EpubReaderView, PdfReaderView, ReaderScrubber, ReaderSettingsFields, ReaderHotkeysDialog, TocList
    │   ├── settings/           # PathBrowserDialog (server-side directory picker), UserMultiSelect (library sharing)
    │   ├── taxonomy/           # TaxonomyCard
    │   ├── ProtectedRoute.tsx
    │   ├── SessionBootstrap.tsx
    │   └── Placeholder.tsx
    ├── hooks/
    │   ├── useAuth.ts          # /api/session, /api/registrations
    │   ├── useBooks.ts         # /api/books, /api/recent_reads, /api/recent_favorites, next_in_series, favorite toggle
    │   ├── useBookMutation.ts  # PATCH / DELETE /api/books/:id
    │   ├── useBulkBookActions.ts  # bulk favorite / unfavorite / destroy
    │   ├── useCollections.ts   # /api/collections (+ collection books)
    │   ├── useLibraries.ts     # /api/libraries + /scans
    │   ├── useFilesystem.ts    # /api/filesystem/browse (path browser)
    │   ├── useUsers.ts         # /api/users (library sharing)
    │   ├── useReadingProgress.ts  # /api/books/:id/progress
    │   ├── useResolvedReaderSettings.ts  # per-book settings merged with user defaults
    │   ├── useUserPreferences.ts  # /api/preferences (user-wide reader defaults)
    │   ├── useScheduledTaskSettings.ts  # /api/scheduled_task_settings
    │   ├── useRegistrationSettings.ts   # /api/registration_settings (public registration toggle)
    │   ├── useTaxonomy.ts      # /api/series /api/authors /api/tags
    │   ├── useTaxonomyListState.ts
    │   ├── useFullscreen.ts useReaderKeyboard.ts
    │   └── useApiTokens.ts     # /api/api_tokens
    ├── stores/
    │   ├── authStore.ts
    │   └── uiStore.ts          # displayMode / sortOrder are persisted
    ├── locales/                # en.json / ja.json (react-i18next)
    ├── lib/
    │   ├── api.ts              # fetch wrapper (credentials: "include")
    │   ├── queryClient.ts
    │   └── utils.ts            # cn = clsx + tailwind-merge
    └── types/api.ts            # User, Book, Library, ReadingProgress, ApiToken, Collection, ...
```

## Memo for Claude Code

- **URL as the single source of truth**: sort / page / search query / library
  view mode (`?view=series`) all live in the URL. That's why state is restored
  after a reload.
- **Keep persisted UI state minimal**: only the grid/list `displayMode` and
  the last-picked `sortOrder` are persisted to localStorage via Zustand
  `persist`. Everything else is in-memory.
- **The cookie session is the source of truth for auth**: `<SessionBootstrap />`
  calls `GET /api/session` once to hydrate `authStore`. By not treating 401 as
  an error, the boot-time auth status settles deterministically to
  `unauthenticated`.
- **Mobile-first**: target baseline is 390x844. The sidebar is fixed at `md:`
  and above; below that it's a Sheet that overlays the content. Book cards
  scale up progressively from `grid-cols-2 → 8`.
- **EPUB Reader / foliate-js integration**: `<foliate-view>` internally hosts
  an iframe inside a shadow DOM. Writing-direction / theme / font-size
  override CSS is injected as a `<style>` block directly under the iframe's
  contentDocument. PATCHing the relocate event's `fraction` (debounced) to
  `/api/books/:id/progress` keeps the cover progress bar and the home
  carousel in sync.
- **Pointer Events**: the progress scrubber and the left/right click zones
  handle mouse and touch uniformly via Pointer Events (hover preview keeps
  tracking during touch drags).
- **shadcn gotcha when adding components**: `npx shadcn@latest add …` sometimes
  generates a literal `@/components/ui/` directory (because there's no
  `baseUrl` in tsconfig). After generation, move them back with
  `mv "@/components/ui/"* src/components/ui/ && rm -rf "@/"`.
