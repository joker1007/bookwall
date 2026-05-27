# Bookwall

電子書籍を自宅サーバで一元管理するためのウェブアプリケーション。

ライブラリディレクトリを再帰的にスキャンして CBZ / EPUB / PDF / 画像ディレクトリ
からメタデータ (タイトル・シリーズ・著者・タグ・ページ数・表紙画像) を取り出し、
ブラウザの React UI からも、OPDS / OPDS-PSE 対応の任意のリーダーアプリからも
読めるようにする。

## サブプロジェクト

| ディレクトリ | 役割 | スタック |
|---|---|---|
| [`server/`](server/) | API + OPDS 配信、SQLite + Active Storage、書籍スキャナ、認証 | Rails 8.1 / Ruby 4.0 / Falcon / SQLite (FTS5) / SolidQueue |
| [`client/`](client/) | `/ui` 配下に乗る SPA。書籍一覧・詳細・検索・お気に入り・設定画面 | Vite + React 19 + TypeScript / Tailwind v4 / shadcn/ui / React Router / TanStack Query / Zustand |

開発時は両方を別ポートで起動し、本番時は client のビルド成果物が server に
同梱されて単一の Docker イメージから配信される。

## 主な機能

- **マルチフォーマットスキャン**: CBZ (ComicInfo.xml 対応) / EPUB / PDF / 画像ディレクトリ
- **メタデータ管理**: タイトル・シリーズ・巻数・著者・タグ・出版日・お気に入り
- **表紙画像**: フォーマットごとに 1 ページ目を抽出して Active Storage に attach、`thumb` / `medium` / `large` の variant を Vips で生成
- **全文検索**: SQLite FTS5 によるタイトル / シリーズ / 著者の AND 検索 (LIKE フォールバック付き)
- **OPDS / OPDS-PSE**: Atom フィードで他のリーダーアプリに配信、ページ単位の画像配信 (`pse:count`) も対応
- **認証**: Cookie セッション (UI 用) と Bearer トークン (OPDS / Reader 用) を併存
- **ダーク UI / モバイル対応**: ダークテーマを起点に 390px〜の viewport で動作

## クイックスタート (開発)

サーバとクライアントを別プロセスで起動する。

### 1. システム要件

- Ruby 4.0.3 (`server/.ruby-version`)
- Node.js 22+ / npm
- SQLite 3 (FTS5 が有効なビルド)
- `libvips`、`poppler-utils` (`pdftocairo` を使う)

### 2. 依存をインストール

```sh
(cd server && bundle install && bin/rails db:setup)
(cd client && npm install)
```

### 3. 開発サーバを一括起動

```sh
cd server
bin/dev          # foreman 経由で web (Falcon, :3000) と client (Vite, :5173) を同時起動
```

`server/Procfile.dev` は `web` (Rails + Falcon) と `client` (Vite) を定義しており、
`bin/dev` はその両方を foreman で立ち上げて出力をマルチプレックスする。foreman は
初回 `bin/dev` 実行時に自動で `gem install` される。

ブラウザは `http://localhost:5173/ui/` を開く。Vite の dev server は `/api`
`/opds` `/rails` `/up` を `http://localhost:3000` に proxy するので、Cookie は
透過する。

`rails s` (引数なし) は IPv6 無効環境で `Errno::EADDRNOTAVAIL` を起こすので、
`bin/dev` または `bundle exec falcon serve --bind http://0.0.0.0:3000` を推奨。

## クイックスタート (本番 / Docker)

リポジトリルートの multi-stage Dockerfile が

1. client を `npm ci && npm run build` してビルド成果物を `dist/` に出力
2. server の gem を `bundle install` し、`dist` を `/rails/public/ui` にコピー
3. Thruster をフロントにして Falcon を起動 (`./bin/thrust bundle exec falcon serve …`)

```sh
docker build -t bookwall .
docker run -d --name bookwall \
  -p 80:80 \
  -e RAILS_MASTER_KEY="$(cat server/config/master.key)" \
  -v bookwall-storage:/rails/storage \
  bookwall
```

- Thruster がポート 80 を listen し、内部の Falcon (`TARGET_PORT=3000`) にプロキシする
- `/` は `/ui/` にリダイレクトされ、`/ui/*` は SPA fallback で `public/ui/index.html` を返す
- `/api/*` `/opds/*` `/up` `/rails/*` は通常の Rails ルートに渡る
- `storage/` には SQLite データベースと Active Storage の表紙ファイルが入るので、永続化したい場合は volume を割り当てる

## アーキテクチャ概略

```
                   ┌──────────────────────────┐
                   │  Browser / OPDS Reader   │
                   └────────────┬─────────────┘
                                │ HTTP/1.1, HTTP/2 (Thruster)
                                ▼
                   ┌──────────────────────────┐
                   │  Thruster (port 80)      │  ← Docker のみ
                   │  static asset cache      │
                   │  X-Sendfile acceleration │
                   └────────────┬─────────────┘
                                │ proxy → :3000
                                ▼
                   ┌──────────────────────────┐
                   │  Falcon (Async/Fiber)    │
                   │  Rails 8.1 API + SPA fwd │
                   └────────────┬─────────────┘
              ┌─────────────────┼─────────────────────┐
              ▼                 ▼                     ▼
   ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐
   │ /api/*         │  │ /opds/*        │  │ /ui/*  (SPA)     │
   │ JSON, Alba     │  │ Atom + PSE     │  │ React + Tailwind │
   │ Cookie sess.   │  │ Bearer / Basic │  │ TanStack Query   │
   └───────┬────────┘  └───────┬────────┘  └──────────────────┘
           │                   │
           ▼                   ▼
   ┌────────────────────────────────────┐
   │ ActiveRecord (SQLite, WAL, FTS5)   │
   │ Active Storage (local disk)        │
   │ SolidQueue (background jobs)       │
   └────────────────────────────────────┘
                                │ enqueue
                                ▼
                   ┌──────────────────────────┐
                   │  ScanLibraryJob          │
                   │  Concurrent::ThreadPool  │
                   │  Parsers (CBZ/EPUB/...)  │
                   │  Covers::Extractor       │
                   └──────────────────────────┘
```

## リポジトリ構成

```
bookwall/
├── README.md             # ← 本ファイル
├── Dockerfile            # multi-stage (client build → server image)
├── .dockerignore
├── .gitignore
├── CLAUDE.md             # プロジェクト要件 (Claude Code 用)
├── server/               # Rails 8.1 API + OPDS。README は server/README.md
└── client/               # Vite + React + TS SPA。README は client/README.md
```

`server/spec/fixtures/files/` 配下のテスト用書籍ファイル (CBZ / EPUB / PDF /
画像ディレクトリ) の入手元・ライセンスは
[`server/spec/fixtures/files/SOURCES.md`](server/spec/fixtures/files/SOURCES.md)
に記録している。

## ライセンス

未指定 (個人用途想定)。fixture の各ファイルは CC-BY 4.0 / Public Domain など
個別のライセンスに従う。
