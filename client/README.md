# Bookwall client

## 技術スタック

- **Vite 8** + **React 19** + **TypeScript** (`verbatimModuleSyntax` 有効)
- **Tailwind CSS v4** (`@tailwindcss/vite`) + **shadcn/ui** (Radix + Tailwind)
- **React Router v7** (`<BrowserRouter basename="/ui">`)
- **TanStack Query v5** — サーバー状態 (書籍 / セッション / トークン / 読書進捗)
- **Zustand** — クライアント状態 (`displayMode`, `sortOrder` を `persist` で localStorage に保存)
- **react-i18next** — 日英 i18n (`src/locales/{en,ja}.json`)
- **foliate-js** — EPUB レンダラ (`<foliate-view>` カスタム要素 / iframe + shadow DOM)
- **PDF.js** — PDF レンダラ
- **lucide-react** — アイコン

## 開発

通常は server 側の `bin/dev` を叩けば foreman が Rails (Falcon) と Vite を両方起動してくれるので、こちらを直接触る必要はない。詳しくはルートの[README](../README.md#3-開発サーバを一括起動) を参照。

client だけ単独で動かしたいときは:

```sh
npm install
npm run dev          # Vite (http://localhost:5173)
```

## ビルド

開発用バンドル:

```sh
npm run build
# → client/dist/ に index.html + assets を吐く
```

サーバに同梱するときは出力先を server/public/ui に切り替える:

```sh
npm run build -- --outDir ../server/public/ui --emptyOutDir
```

see. [Dockerfile](../Dockerfile)

## ディレクトリ構成

```
client/
├── index.html                  # <html lang="ja" class="dark">
├── vite.config.ts              # base="/ui/" + dev proxy + path alias @/
├── tsconfig.app.json           # paths: { "@/*": ["./src/*"] }
├── components.json             # shadcn/ui 設定
└── src/
    ├── main.tsx
    ├── App.tsx                 # Router + QueryClientProvider + SessionBootstrap
    ├── index.css               # Tailwind v4 + shadcn CSS variables
    ├── routes/                 # 1 ファイル = 1 ルート
    │   ├── _layout.tsx         #   AppShell をマウントするだけの薄いラッパ
    │   ├── home.tsx            #   "/" 最近読んだ本のカルーセル + 最近追加された書籍
    │   ├── login.tsx           #   "/login" 公開
    │   ├── signup.tsx          #   "/signup" 公開
    │   ├── books.detail.tsx    #   "/books/:id"
    │   ├── books.read.tsx      #   "/books/:id/read" CBZ / PDF / image_dir リーダー (EPUB は内包)
    │   ├── libraries.detail.tsx
    │   ├── series.detail.tsx
    │   ├── authors.detail.tsx
    │   ├── tags.detail.tsx
    │   ├── series.tsx authors.tsx tags.tsx
    │   ├── favorites.tsx
    │   ├── search.tsx
    │   ├── settings.libraries.tsx
    │   └── settings.api_tokens.tsx
    ├── components/
    │   ├── ui/                 # shadcn 生成物 (button, card, dialog, table, …)
    │   ├── layout/             # AppShell, Header, Sidebar
    │   ├── books/              # BookListView, BookCard, BookRow, BookCover (進捗バー overlay 付き), BookEditDialog, RecentReadsCarousel
    │   ├── reader/             # EpubReaderView, ReaderScrubber, ReaderHotkeysDialog
    │   ├── taxonomy/           # TaxonomyCard
    │   ├── ProtectedRoute.tsx
    │   ├── SessionBootstrap.tsx
    │   └── Placeholder.tsx
    ├── hooks/
    │   ├── useAuth.ts          # /api/session, /api/registrations
    │   ├── useBooks.ts         # /api/books, /api/recent_reads, favorite toggle
    │   ├── useBookMutation.ts  # PATCH / DELETE /api/books/:id
    │   ├── useLibraries.ts     # /api/libraries + /scans
    │   ├── useReadingProgress.ts  # /api/books/:id/progress
    │   ├── useUserPreferences.ts  # /api/preferences (user-wide reader defaults)
    │   ├── useTaxonomy.ts      # /api/series /api/authors /api/tags
    │   └── useApiTokens.ts     # /api/api_tokens
    ├── stores/
    │   ├── authStore.ts
    │   └── uiStore.ts          # displayMode / sortOrder は persist
    ├── locales/                # en.json / ja.json (react-i18next)
    ├── lib/
    │   ├── api.ts              # fetch wrapper (credentials: "include")
    │   ├── queryClient.ts
    │   └── utils.ts            # cn = clsx + tailwind-merge
    └── types/api.ts            # User, Book, Library, ReadingProgress, ApiToken, ...
```

## Memo for Claude Code

- **URL を SSoT に**: ソート / ページ / 検索クエリ / ライブラリビューモード
  (`?view=series`) は URL に乗せる。reload しても状態が復元されるのはこのおかげ。
- **永続化する UI state は最小限**: グリッド/リスト切替の `displayMode` と
  最後に選んだ `sortOrder` を Zustand `persist` で localStorage に保存。他は
  メモリのみ。
- **認証は Cookie session が真**: `<SessionBootstrap />` が
  `GET /api/session` を 1 回叩いて authStore を hydrate する。401 を error 扱い
  しないことで、起動直後の auth status が `unauthenticated` に確定する。
- **モバイルファースト**: 基準は 390x844。サイドバーは `md:` 以上で固定、未満は
  Sheet で覆い被せる。書籍カードは `grid-cols-2 → 8` で順次広がる。
- **EPUB Reader の foliate-js 連携**: `<foliate-view>` は内部で iframe を
  shadow DOM 内にホストする。書字方向・テーマ・フォントサイズの override CSS
  は iframe contentDocument 直下に `<style>` を流し込む。relocate event の
  `fraction` を debounce 付きで `/api/books/:id/progress` に PATCH すると、
  表紙の進捗バーやホームのカルーセルが同期する。
- **Pointer Events**: 進捗スクラバーや左右クリックゾーンはマウス / タッチ
  両方を Pointer Events で扱う (タッチドラッグ中も hover プレビューが追従)。
- **shadcn の add 時の落とし穴**: `npx shadcn@latest add …` が
  `@/components/ui/` を literal なディレクトリとして生成することがある (tsconfig に
  baseUrl が無いため)。生成後は `mv "@/components/ui/"* src/components/ui/ &&
  rm -rf "@/"` で本来のパスに移す。
