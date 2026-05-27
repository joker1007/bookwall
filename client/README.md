# Bookwall client

Bookwall の Web UI。`/ui` prefix の下に乗る React SPA で、書籍一覧 / 詳細 /
検索 / お気に入り / 設定 (ライブラリ管理 / API トークン管理) を提供する。

## 技術スタック

- **Vite 8** + **React 19** + **TypeScript** (`verbatimModuleSyntax` 有効)
- **Tailwind CSS v4** (`@tailwindcss/vite`) + **shadcn/ui** (Radix + Tailwind)
- **React Router v7** (`<BrowserRouter basename="/ui">`)
- **TanStack Query v5** — サーバー状態 (書籍 / セッション / トークン)
- **Zustand** — クライアント状態 (`displayMode` のみ `persist` で localStorage に保存)
- **lucide-react** — アイコン

ダークテーマを起点 (`<html class="dark">`) として、shadcn の CSS variables を
`oklch` で定義している。light テーマを追加するときは `:root` の値を上書きする
セレクタを足せばよい。

## 開発

通常は server 側の `bin/dev` を叩けば foreman が Rails (Falcon) と Vite を
両方起動してくれるので、こちらを直接触る必要はない。詳しくはルートの
[README](../README.md#3-開発サーバを一括起動) を参照。

client だけ単独で動かしたいときは:

```sh
npm install
npm run dev          # Vite (http://localhost:5173)
```

Vite の dev server は `/api` `/opds` `/rails` `/up` を `http://localhost:3000`
(`server/`) にプロキシするので、ブラウザでは `http://localhost:5173/ui/` だけを
開けばよい。Cookie もプロキシ越しに透過する。

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

リポジトリルートの Dockerfile はこのビルドを自動でやり、成果物を
`/rails/public/ui` にコピーする。詳しくはルートの
[`README.md`](../README.md#クイックスタート-本番--docker) を参照。

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
    │   ├── home.tsx            #   "/" (最近追加された書籍)
    │   ├── login.tsx           #   "/login" 公開
    │   ├── signup.tsx          #   "/signup" 公開
    │   ├── books.detail.tsx    #   "/books/:id"
    │   ├── libraries.detail.tsx
    │   ├── series.detail.tsx
    │   ├── authors.detail.tsx
    │   ├── tags.detail.tsx
    │   ├── favorites.tsx
    │   ├── search.tsx
    │   ├── settings.libraries.tsx
    │   └── settings.api_tokens.tsx
    ├── components/
    │   ├── ui/                 # shadcn 生成物 (button, card, dialog, table, …)
    │   ├── layout/             # AppShell, Header, Sidebar
    │   ├── books/              # BookListView, BookCard, BookRow, BookCover, BookEditDialog
    │   ├── ProtectedRoute.tsx
    │   ├── SessionBootstrap.tsx
    │   └── Placeholder.tsx
    ├── hooks/
    │   ├── useAuth.ts          # /api/session, /api/registrations
    │   ├── useBooks.ts         # /api/books, favorite toggle
    │   ├── useBookMutation.ts  # PATCH / DELETE /api/books/:id
    │   ├── useLibraries.ts     # /api/libraries + /scans
    │   └── useApiTokens.ts     # /api/api_tokens
    ├── stores/
    │   ├── authStore.ts
    │   └── uiStore.ts          # displayMode は persist
    ├── lib/
    │   ├── api.ts              # fetch wrapper (credentials: "include")
    │   ├── queryClient.ts
    │   └── utils.ts            # cn = clsx + tailwind-merge
    └── types/api.ts            # User, Book, Library, ApiToken, ...
```

## 設計メモ

- **URL を SSoT に**: ソート / ページ / 検索クエリは `?sort=…&page=…&q=…`、
  選択中の library/series/author/tag/book は path に乗せる。reload しても状態が
  復元されるのはこのおかげ。
- **永続化する UI state は最小限**: グリッド/リスト切替の `displayMode` だけを
  Zustand `persist` で localStorage に保存。他はメモリのみ。
- **認証は Cookie session が真**: `<SessionBootstrap />` が
  `GET /api/session` を 1 回叩いて authStore を hydrate する。401 を error 扱い
  しないことで、起動直後の auth status が `unauthenticated` に確定する。
- **モバイルファースト**: 基準は 390x844。サイドバーは `md:` 以上で固定、未満は
  Sheet で覆い被せる。書籍カードは `grid-cols-2 → 6` で順次広がる。
- **shadcn の add 時の落とし穴**: `npx shadcn@latest add …` が
  `@/components/ui/` を literal なディレクトリとして生成することがある (tsconfig に
  baseUrl が無いため)。生成後は `mv "@/components/ui/"* src/components/ui/ &&
  rm -rf "@/"` で本来のパスに移す。
