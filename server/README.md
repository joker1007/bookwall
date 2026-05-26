# Bookwall server

Rails 8.1 / Falcon ベースの電子書籍管理 API サーバー。CBZ / EPUB / PDF /
画像ディレクトリを再帰的にスキャンし、メタデータ・タグ・お気に入りを管理しつつ、
OPDS / OPDS-PSE フィードと REST API でクライアント (`../client`) や任意の OPDS
リーダーに配信する。

## システム要件

- Ruby 4.0.3 (`.ruby-version`)
- SQLite 3 (FTS5 が有効なビルド)
- libvips (cover variant 生成に必要)
- poppler-utils の `pdftocairo` (PDF 1 ページ目のラスタライズに使用)

## セットアップ

```sh
bundle install
bin/rails db:setup
```

`db:setup` は development / test の SQLite データベースを作成し、`db/structure.sql` を
適用する (FTS5 仮想テーブルがあるため `schema_format = :sql`)。

## 起動

開発時:

```sh
bin/dev  # Procfile.dev 経由で Falcon を起動 (foreman が必要、自動インストール)
```

または直接:

```sh
bundle exec falcon serve --bind http://0.0.0.0:3000
```

非同期ジョブ (production):

```sh
bin/jobs  # SolidQueue ワーカー
```

## テスト / lint / セキュリティ

```sh
bundle exec rspec          # RSpec
bin/rubocop                # rubocop (rubocop-rails-omakase ベース)
bin/brakeman --no-pager    # Brakeman
```

## 主要エンドポイント

| メソッド + パス | 用途 |
|---|---|
| `POST   /api/registrations` | サインアップ |
| `POST   /api/session` | ログイン (Cookie セッション発行) |
| `DELETE /api/session` | ログアウト |
| `POST   /api/api_tokens` | OPDS / Reader 用 Bearer トークン発行 |
| `GET    /api/libraries` | ライブラリ CRUD |
| `GET    /api/books` | 検索 (`q`, `sort`, `library_id`, `series_id`, `author_id`, `tag_id`, `favorites_only`) |
| `PATCH  /api/books/:id` | メタ編集 (タイトル / 著者名 / タグ名など) |
| `POST   /api/books/:id/favorite` | お気に入り追加 |
| `GET    /opds` | OPDS ルート (Atom navigation) |
| `GET    /opds/recent` | 新着フィード |
| `GET    /opds/libraries/:library_id` | ライブラリ別 acquisition フィード |
| `GET    /opds/books/:book_id/file` | 書籍ダウンロード |
| `GET    /opds/books/:book_id/pages/:n` | OPDS-PSE ページ画像 |

OPDS は Bearer トークン (`Authorization: Bearer …`) と HTTP Basic の両方に対応。

## アーキテクチャ概略

- `app/services/parsers/` — フォーマット別 Parser (CBZ / EPUB / PDF / image_dir)。共通 IF: `#metadata`, `#page_count`, `#cover_bytes`, `#page_bytes(i)`
- `app/services/scanners/` — `LibraryScanner` がディレクトリを再帰走査し、差分検知してから `Concurrent::FixedThreadPool` で並列パース。書き込みはメインスレッドに集約 (SQLite 単一ライタ)。
- `app/services/covers/` — Parser 経由で取得した cover bytes を Active Storage に attach、`thumb / medium / large` の variant を持つ。
- `app/services/books/` — FTS5 (`books_fts`) との同期 (`FtsIndex.upsert/delete`) と検索クエリビルダ (`Books::Search`)。
- `app/services/opds/` — Nokogiri ベースの Atom + OPDS-PSE feed builder。

## 既知の注意点

- `db/structure.sql` は SQLite FTS5 の shadow table (`books_fts_*`) を含むが、`db:test:prepare` での parse 警告は SQLite が自動再生成するため動作上の問題はない。
- development では `config.active_job.queue_adapter` がデフォルト (`:async`)。SolidQueue を試す場合は `Procfile.dev` の `jobs` 行を有効にして `solid_queue:install` の migrate を適用する。
