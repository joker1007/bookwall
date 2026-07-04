# Bookwall server

[English README](./README.md)

## Setup

```sh
bundle install
bin/rails db:setup
```

`db:setup` は development / test の SQLite データベースを作成し、`db/structure.sql` を
適用する (FTS5 仮想テーブルがあるため `schema_format = :sql`)。

## 起動

開発時:

```sh
bin/dev  # foreman 経由で web (Falcon, :3000) と client (Vite, :5173) を同時起動
         # foreman は初回実行時に自動で gem install される
```


Rails だけ単独で動かしたいときは:

```sh
bundle exec falcon serve --bind http://0.0.0.0:3000
```


非同期ジョブ (production):

```sh
bin/jobs  # SolidQueue ワーカー
```

## Test / lint

```sh
bundle exec rspec          # RSpec
bin/rubocop                # rubocop (rubocop-rails-omakase ベース)
bin/brakeman --no-pager    # Brakeman
```

## 主要エンドポイント

| メソッド + パス | 用途 |
|---|---|
| `GET    /` | `/ui/` への 301 リダイレクト |
| `GET    /ui` `/ui/*` | SPA fallback (`public/ui/index.html` を返す) |
| `POST   /api/registrations` | サインアップ |
| `POST   /api/session` | ログイン (Cookie セッション発行) |
| `DELETE /api/session` | ログアウト |
| `POST   /api/api_tokens` | OPDS / Reader 用 Bearer トークン発行 |
| `GET    /api/libraries` | ライブラリ CRUD |
| `POST   /api/libraries/:id/scans` | `ScanLibraryJob` を enqueue (202) |
| `GET    /api/books` | 検索 (`q`, `sort`, `library_id`, `series_id`, `author_id`, `tag_id`, `collection_id`, `favorites_only`) |
| `PATCH  /api/books/:id` | メタ編集 (タイトル / 著者名 / タグ名など) |
| `POST   /api/books/:id/favorite` | お気に入り追加 |
| `POST   /api/books/bulk_favorite` `DELETE` / `POST /api/books/bulk_destroy` | 一括お気に入り追加 / 解除 / 削除 |
| `GET    /api/books/:id/next_in_series` | 同一シリーズの次巻 (リーダーのロールオーバー用) |
| `GET    /api/books/:id/file` | 書籍本体 (EPUB / CBZ / PDF bytes) を Web Reader 用に配信 (Cookie auth) |
| `GET    /api/books/:id/pages/:n` | Web Reader 用の CBZ / image_dir ページ画像 (Cookie auth) |
| `GET    /api/books/:id/progress` `PATCH` | 読書進捗 (current_page / epub_cfi / progress_fraction / per-book reader settings) |
| `GET    /api/recent_reads` `/api/recent_favorites` | サインインユーザの最近の本 (ホームのカルーセル用) |
| `GET    /api/preferences` `PATCH` | ユーザ全体のリーダー既定値 (font_size / theme / writing_mode / direction / scale / spread / preload_ahead) |
| `GET    /api/scheduled_task_settings` `PATCH` | 日次スケジュールスキャンのトグル |
| `GET    /api/series` `/api/authors` `/api/tags` | タクソノミー一覧 (各 first_book を batch preload) |
| `CRUD   /api/collections` (+ `/api/collections/:id/books`) | ユーザー定義コレクションと所属書籍 |
| `GET    /api/users` | ユーザー一覧 (ライブラリ共有用) |
| `GET    /api/filesystem/browse` | サーバーサイドのディレクトリブラウザ (ライブラリパス選択用) |
| `GET    /opds` | OPDS ルート (Atom navigation。進捗同期の capability link を広告) |
| `GET    /opds/recent` `/recent-reads` `/favorites` | acquisition フィード |
| `GET    /opds/libraries(/:id)` `/series(/:id)` `/tags(/:id)` `/collections(/:id)` | navigation / acquisition フィード (acquisition フィードはタグファセット付き) |
| `GET    /opds/books/:book_id/file.:format` | 書籍ダウンロード (acquisition link にファイルサイズ付き。image_dir はオンザフライで CBZ 化) |
| `GET    /opds/books/:book_id/pages/:n` | OPDS-PSE ページ画像 |
| `GET    /opds/books/:book_id/progress` `PUT` | first-party の読書進捗同期 (Android アプリが利用) |

OPDS は Bearer トークン (`Authorization: Bearer …`) と HTTP Basic の両方に対応。

## アーキテクチャ概略

- `app/services/parsers/` — フォーマット別 Parser (CBZ / EPUB / PDF / image_dir)。共通 IF: `#metadata`, `#page_count`, `#cover_bytes`, `#page_bytes(i)`。EPUB は `dc:subject` をタグ、`calibre:series` / `calibre:series_index` をシリーズ・巻数として取り込む。
- `app/services/scanners/` — `LibraryScanner` がディレクトリを再帰走査し、差分検知してから `Concurrent::FixedThreadPool` で並列パース。書き込みはメインスレッドに集約 (SQLite 単一ライタ)。シリーズ未設定の本は親ディレクトリ名を fallback として登録する。`Book#file_path` はライブラリ root からの相対パスで保存し、`Book#absolute_path` で `library.path + file_path` に解決する。
- `app/services/covers/` — Parser 経由で取得した cover bytes を Active Storage に attach、`thumb / medium / large` の variant を持つ。
- `app/services/books/` — FTS5 (`books_fts`) との同期 (`FtsIndex.upsert/delete`)、検索クエリビルダ (`Books::Search`)、`Books::PageStreaming` (CBZ / image_dir のページ画像配信)、`Books::FirstBookPreloader` (タクソノミー index 用のバッチローダ)。
- `app/serializers/concerns/reading_progress_fraction.rb` — Book + ReadingProgress から 0..1 の進捗 fraction を計算 (CBZ 系は `current_page / (page_count - 1)`、EPUB は `progress_fraction` カラム)。BookSerializer の `reading_progress` attribute で利用。
- `app/services/opds/` — Nokogiri ベースの Atom + OPDS-PSE feed builder。
- `app/controllers/spa_controller.rb` — `/ui` 配下のリクエストに対して `public/ui/index.html` を返す。ビルドされた client を同梱したときだけ動く (なければ 404)。

## client (React SPA) の同梱

本番 image では `client/` を `npm run build` した成果物が `public/ui/` に置かれるため、Rails は `/ui/*` 配下のリクエストすべてに対して `index.html` を返す(`SpaController`)。Thruster (Dockerfile の前段) が `public/ui/assets/*` のJS/CSS を直接配信する。

開発時に手動で確認したい場合:

```sh
cd ../client
npm run build -- --outDir ../server/public/ui --emptyOutDir
cd ../server
bundle exec falcon serve --bind http://0.0.0.0:3000
# → http://localhost:3000/ で SPA が立ち上がる
```

## 既知の注意点

- `db/structure.sql` は SQLite FTS5 の shadow table (`books_fts_*`) を含むが、`db:test:prepare` での parse 警告は SQLite が自動再生成するため動作上の問題はない。
