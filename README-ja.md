# Bookwall

電子書籍管理と Web リーダー (Rails + React)、およびコンパニオンの Android リーダーアプリ。

[English README](./README.md)

## デモ

Playwright で収録したガイドツアー (サインアップ → ライブラリスキャン → グリッド/リスト切替 → CBZ リーダー → 横書き EPUB → 縦書き EPUB)。[`docs/demo.mp4`](./docs/demo.mp4) (約 1 分 20 秒、2.9 MB、H.264)。

<div>
<video src="https://raw.githubusercontent.com/joker1007/bookwall/main/docs/demo.mp4" controls width="720"></video>
</div>

再生成は以下のコマンド:

```sh
cd client && npm run demo:video
# Playwright は client/test-results/.../video.webm を吐くので、GitHub の
# README ビューワで再生できる mp4 に再エンコードする:
ffmpeg -y -i client/test-results/tour-Bookwall-guided-tour-desktop-chromium/video.webm \
       -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -movflags +faststart -an \
       docs/demo.mp4
```

## サブプロジェクト

| ディレクトリ | 役割 | スタック |
|---|---|---|
| [`server/`](server/) | API + OPDS 配信、SQLite + Active Storage、書籍スキャナ、認証 | Rails 8.1 / Ruby 4.0 / Falcon / Thruster / SQLite (FTS5) / SolidQueue |
| [`client/`](client/) | `/ui` 配下に乗る SPA。書籍一覧・詳細・検索・お気に入り・コレクション・設定画面・Web Reader | Vite + React 19 + TypeScript / Tailwind v4 / shadcn/ui / React Router / TanStack Query / Zustand / foliate-js / PDF.js |
| [`apps/android/`](apps/android/) | OPDS リーダーアプリ。カタログ閲覧、ストリーミング + オフライン読書、進捗の双方向同期 | Kotlin / Jetpack Compose / Hilt / Room / WorkManager / Coil / foliate-js (WebView) |

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

### ライブラリ管理 UI
- **コレクション**: ユーザー定義の書籍コレクション (OPDS フィードでも配信)
- **一括操作**: 複数選択してお気に入り追加 / 解除 / 削除
- **ライブラリ共有**: 選択したユーザーとライブラリを共有 (非オーナーは読み取りのみ)
- **設定画面**: サーバーサイドのディレクトリブラウザでライブラリパスを登録、日次スケジュールスキャンのトグル

### Web Reader
- **CBZ / PDF / 画像ディレクトリ**: ページ画像配信 + クライアント側で表示。見開き / 1 ページ表示、LTR / RTL、4 種類のスケールモード
- **EPUB**: foliate-js ベース。目次、フォントサイズ、テーマ (light / dark / sepia)、書字方向 (auto 自動判定 / horizontal / vertical) を per-book で保存
- **読書進捗**: ページ位置 (CBZ) と CFI + fraction (EPUB) を自動保存し、表紙・ホームのカルーセル・書籍詳細に反映
- **スクラバー**: 任意ページへ直接ジャンプ。CBZ はサムネ、EPUB は章ラベルをプレビュー
- **サムネイル一覧**: 全ページのサムネイルをオーバーレイ表示 (CBZ / 画像ディレクトリ)。遅延ロードで、クリックしたページへジャンプ
- **キーボードナビ**: ページ送り・見開きトグル・1 ページ送り。`?` でショートカット一覧
- **シリーズ ロールオーバー**: 最終ページを越えて送るとシリーズの次巻へ続けて読める

### 配信・連携
- **OPDS / OPDS-PSE**: Atom フィードで他のリーダーアプリに配信 — 新着 / 最近読んだ本 / お気に入り / ライブラリ別 / シリーズ / タグ / コレクション。タグファセットとページストリーミング (PSE) 対応
- **進捗同期**: OPDS ルートに first-party の進捗エンドポイントを capability link として広告。Android アプリはこれで読書位置を push / pull する
- **認証**: Cookie セッション (UI 用) と Bearer トークン (OPDS / Reader 用) を併存。サインアップは最初のアカウント作成まで開放され、以降は設定画面でパブリック登録を有効にしない限り閉じる
- **モバイル対応**: 390px〜の viewport で動作

### Android アプリ
- **OPDS クライアント**: 複数サーバー登録 (Basic 認証 / 自己署名証明書)、ソート / フィルタ / タグファセット付きのカタログ閲覧
- **リーダー**: 画像系は OPDS-PSE ストリーミング (見開き・RTL)。EPUB は web reader と同一の foliate-js エンジンで描画し CFI 進捗が相互運用可能
- **オフラインキャッシュ**: サイズ上限付きのバックグラウンドDL、完全オフラインで動くダウンロード済み画面、読んだ本の自動キャッシュ。オフライン中の読書進捗は再接続時にサーバーへ同期

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
├── README.md             # English (top-level)
├── README-ja.md          # ← 本ファイル (日本語訳)
├── LICENSE               # MIT
├── Dockerfile            # multi-stage (client build → server image)
├── .dockerignore
├── .gitignore
├── CLAUDE.md             # プロジェクト要件 (Claude Code 用)
├── docs/                 # demo.mp4 (Playwright で録ったガイドツアー、H.264)
├── server/               # Rails 8.1 API + OPDS。README は server/README.md
├── client/               # Vite + React + TS SPA。README は client/README.md
└── apps/
    └── android/          # Android OPDS リーダーアプリ。README は apps/android/README.md
```

`server/spec/fixtures/files/` 配下のテスト用書籍ファイル (CBZ / EPUB / PDF / 画像ディレクトリ) の入手元・ライセンスは[`server/spec/fixtures/files/SOURCES.md`](server/spec/fixtures/files/SOURCES.md)。

## ライセンス

MIT License.
