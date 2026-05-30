# Bookwall server

[日本語版 README はこちら / Japanese README](./README-ja.md)

## Setup

```sh
bundle install
bin/rails db:setup
```

`db:setup` creates the SQLite databases for development / test and applies
`db/structure.sql` (we use `schema_format = :sql` because of the FTS5 virtual
tables).

## Running

For development:

```sh
bin/dev  # Starts web (Falcon, :3000) and client (Vite, :5173) together via foreman.
         # foreman is auto-installed via gem install on the first run.
```


To run only Rails standalone:

```sh
bundle exec falcon serve --bind http://0.0.0.0:3000
```


Background jobs (production):

```sh
bin/jobs  # SolidQueue worker
```

## Test / lint

```sh
bundle exec rspec          # RSpec
bin/rubocop                # rubocop (based on rubocop-rails-omakase)
bin/brakeman --no-pager    # Brakeman
```

## Main endpoints

| Method + Path | Purpose |
|---|---|
| `GET    /` | 301 redirect to `/ui/` |
| `GET    /ui` `/ui/*` | SPA fallback (returns `public/ui/index.html`) |
| `POST   /api/registrations` | Sign-up |
| `POST   /api/session` | Login (issues a cookie session) |
| `DELETE /api/session` | Logout |
| `POST   /api/api_tokens` | Issue a Bearer token for OPDS / Reader |
| `GET    /api/libraries` | Library CRUD |
| `POST   /api/libraries/:id/scans` | Enqueue `ScanLibraryJob` (202) |
| `GET    /api/books` | Search (`q`, `sort`, `library_id`, `series_id`, `author_id`, `tag_id`, `favorites_only`) |
| `PATCH  /api/books/:id` | Edit metadata (title / author names / tag names, etc.) |
| `POST   /api/books/:id/favorite` | Add to favorites |
| `GET    /api/books/:id/file` | Serve the book itself (EPUB / CBZ / PDF bytes) to the Web Reader (cookie auth) |
| `GET    /api/books/:id/pages/:n` | CBZ / image_dir page image for the Web Reader (cookie auth) |
| `GET    /api/books/:id/progress` `PATCH` | Reading progress (current_page / epub_cfi / progress_fraction / per-book reader settings) |
| `GET    /api/recent_reads` | The signed-in user's 12 most recent books (for the home carousel) |
| `GET    /api/preferences` `PATCH` | User-wide reader defaults (font_size / theme / writing_mode / direction / scale / spread / preload_ahead) |
| `GET    /api/series` `/api/authors` `/api/tags` | Taxonomy indexes (each with first_book batch preload) |
| `GET    /opds` | OPDS root (Atom navigation) |
| `GET    /opds/recent` | Recent additions feed |
| `GET    /opds/libraries/:library_id` | Per-library acquisition feed |
| `GET    /opds/books/:book_id/file` | Book download |
| `GET    /opds/books/:book_id/pages/:n` | OPDS-PSE page image |

OPDS accepts both Bearer tokens (`Authorization: Bearer …`) and HTTP Basic.

## Architecture overview

- `app/services/parsers/` — Per-format parsers (CBZ / EPUB / PDF / image_dir). Common interface: `#metadata`, `#page_count`, `#cover_bytes`, `#page_bytes(i)`. EPUB imports `dc:subject` as tags and `calibre:series` / `calibre:series_index` as series name / volume number.
- `app/services/scanners/` — `LibraryScanner` recursively walks a directory, detects diffs, then parses in parallel via `Concurrent::FixedThreadPool`. All writes are funneled to the main thread (single SQLite writer). Books without a series fall back to the parent directory name. `Book#file_path` is stored as a path relative to the library root, and `Book#absolute_path` resolves it as `library.path + file_path`.
- `app/services/covers/` — Attaches the cover bytes obtained via parsers to Active Storage; exposes `thumb / medium / large` variants.
- `app/services/books/` — Sync with FTS5 (`books_fts`) via `FtsIndex.upsert/delete`, the search query builder (`Books::Search`), `Books::PageStreaming` (CBZ / image_dir page image delivery), and `Books::FirstBookPreloader` (batch loader for taxonomy index pages).
- `app/serializers/concerns/reading_progress_fraction.rb` — Computes a 0..1 progress fraction from Book + ReadingProgress (CBZ family: `current_page / (page_count - 1)`; EPUB: the `progress_fraction` column). Used by `BookSerializer`'s `reading_progress` attribute.
- `app/services/opds/` — Nokogiri-based Atom + OPDS-PSE feed builder.
- `app/controllers/spa_controller.rb` — Returns `public/ui/index.html` for requests under `/ui`. Only effective when the built client is bundled (otherwise 404).

## Bundling the client (React SPA)

In production images, `client/` is built via `npm run build` and the output lands in `public/ui/`, so Rails returns `index.html` for every request under `/ui/*` (`SpaController`). Thruster (the front layer in the Dockerfile) directly serves the JS / CSS under `public/ui/assets/*`.

To verify this manually in development:

```sh
cd ../client
npm run build -- --outDir ../server/public/ui --emptyOutDir
cd ../server
bundle exec falcon serve --bind http://0.0.0.0:3000
# → The SPA boots at http://localhost:3000/
```

## Known caveats

- `db/structure.sql` includes the SQLite FTS5 shadow tables (`books_fts_*`); SQLite regenerates them automatically, so the parse warnings emitted by `db:test:prepare` are harmless.
