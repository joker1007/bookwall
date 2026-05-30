# Bookwall

電子書籍管理とWebリーダーを提供するRailsアプリケーション。

## サブプロジェクト

| ディレクトリ | 役割 | スタック |
|---|---|---|
| [`server/`](server/) | API + OPDS 配信、SQLite + Active Storage、書籍スキャナ、認証 | Rails 8.1 / Ruby 4.0 / Falcon / Thruster / SQLite (FTS5) / SolidQueue |
| [`client/`](client/) | `/ui` 配下に乗る SPA。書籍一覧・詳細・検索・お気に入り・設定画面・Web Reader | Vite + React 19 + TypeScript / Tailwind v4 / shadcn/ui / React Router / TanStack Query / Zustand / foliate-js / PDF.js |

## 主な機能

### サポートフォーマット
- CBZ (ComicInfo.xml 対応)
- EPUB
- PDF
- 画像ディレクトリ

### スキャン・メタデータ
- **EPUB 拡張メタ**: `dc:subject` をタグ、Calibre の `calibre:series` / `calibre:series_index` をシリーズ・巻数として取り込む
- **シリーズ フォールバック**: メタデータにシリーズが無い書籍は親ディレクトリ名を採用
- **表紙画像**: フォーマットごとに 1 ページ目を抽出して Active Storageに保存
- **全文検索**: SQLite FTS5 によるタイトル / シリーズ / 著者の AND 検索
- **タクソノミー閲覧**: シリーズ・著者・タグ別の一覧 + サムネ表示。ライブラリ詳細はブック / シリーズビューをトグル可能
- **ソート**: 新着順・登録日順・タイトル順・シリーズ順・著者順 (昇降)

### Web Reader
- **CBZ / PDF / 画像ディレクトリ**: ページ画像配信 + クライアント側で表示。見開き / 1 ページ表示、LTR / RTL、4 種類のスケールモード
- **EPUB**: foliate-js ベース。目次、フォントサイズ、テーマ (light / dark / sepia)、書字方向 (auto 自動判定 / horizontal / vertical) を per-book で保存
- **読書進捗**: ページ位置 (CBZ) と CFI + fraction (EPUB) を自動保存。表紙の下端に進捗バーをオーバーレイ、ホーム画面の最近読んだ本カルーセル、書籍詳細ページに反映
- **ホバーで現れるスクラバー**: 下端から引き出して任意ページに直接ジャンプ。CBZ はホバー位置のサムネを、EPUB は対応する章ラベルをプレビュー表示
- **キーボードナビ + ヒント**: 矢印 / Space / Backspace / Esc に加え、CBZ では `2` で見開きトグル、`Shift + 矢印` で 1 ページだけ送り。`?` でショートカット一覧
- **クリック領域とホバーフィードバック**: 左右 12% のみクリッカブル (中央の文字選択を妨げない)、ホバーティント付き

### 配信・連携
- **OPDS / OPDS-PSE**: Atom フィードで他のリーダーアプリに配信
- **認証**: Cookie セッション (UI 用) と Bearer トークン (OPDS / Reader 用) を併存
- **モバイル対応**: 390px〜の viewport で動作

## Development

### 1. システム要件

- Ruby 4.0.3+
- Node.js 22+ / npm
- SQLite 3 (FTS5 が有効なビルド)

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

## Docker image

see. [Dockerfile](./Dockerfile)

### Example

```sh
docker build -t bookwall .
docker run -d --name bookwall \
  -p 8237:8237 \
  -e RAILS_MASTER_KEY="$(cat server/config/master.key)" \
  -v /path/to/your/bookwall-config:/config \
  -v /path/to/your/books:/books:ro \
  --restart unless-stopped \
  --init \
  bookwall
```

- Thruster がポート **8237** を listen し、内部の Falcon (`TARGET_PORT=3000`) にプロキシする
- **`/config` ボリューム**には SQLite データベース (primary / cache / queue / cable) と Active Storage の表紙ファイルを保持する。
- ライブラリ本体 (CBZ / EPUB / PDF 等) は別ボリュームでマウントし、Bookwall の設定画面でそのパスをライブラリとして登録する

## アーキテクチャ概略

```
                   ┌──────────────────────────┐
                   │  Browser / OPDS Reader   │
                   └────────────┬─────────────┘
                                │ HTTP/1.1, HTTP/2 (Thruster)
                                ▼
                   ┌──────────────────────────┐
                   │  Thruster (port 8237)    │  ← Docker のみ
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
                   │  SolidQueue jobs         │
                   │   ScanLibraryJob         │
                   │   DestroyLibraryJob      │
                   │   Books::FtsSyncJob      │
                   │   Scheduled* (cron)      │
                   │  Concurrent::ThreadPool  │
                   │  Parsers (CBZ/EPUB/...)  │
                   │  Covers::Extractor       │
                   └──────────────────────────┘
```

その他に `/` → `/ui/` への redirect と、Rails 標準の `/up` ヘルスチェックがルーティングされている。`Scheduled*` ジョブ (ScheduledLibraryScanJob / ScheduledCleanupJob) は `config/recurring.yml` で SolidQueue が毎日起動する。

書籍ファイルは `Book.file_path` にライブラリ root からの相対パスで保存し、ランタイムで`library.path + file_path` に解決する。

## リポジトリ構成

```
bookwall/
├── README.md             # ← 本ファイル
├── LICENSE               # MIT
├── Dockerfile            # multi-stage (client build → server image)
├── .dockerignore
├── .gitignore
├── CLAUDE.md             # プロジェクト要件 (Claude Code 用)
├── server/               # Rails 8.1 API + OPDS。README は server/README.md
└── client/               # Vite + React + TS SPA。README は client/README.md
```

`server/spec/fixtures/files/` 配下のテスト用書籍ファイル (CBZ / EPUB / PDF / 画像ディレクトリ) の入手元・ライセンスは[`server/spec/fixtures/files/SOURCES.md`](server/spec/fixtures/files/SOURCES.md)。

## ライセンス

MIT License.
