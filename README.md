# Bookwall

A Rails application that provides e-book management and a web-based reader.

[日本語版 README はこちら / Japanese README](./README-ja.md)

## Demo

A guided tour (signup → library scan → grid/list browse → CBZ reader → horizontal EPUB → vertical EPUB) recorded with Playwright. See [`docs/demo.mp4`](./docs/demo.mp4) (≈1.3 min, 2.9 MB, H.264).

https://github.com/user-attachments/assets/1400a191-5fb3-4c34-a9fe-e6dc734a637e

Regenerate it with:

```sh
cd client && npm run demo:video
# Playwright outputs client/test-results/.../video.webm. Transcode it to mp4
# so GitHub's README viewer can play it inline:
ffmpeg -y -i client/test-results/tour-Bookwall-guided-tour-desktop-chromium/video.webm \
       -c:v libx264 -preset slow -crf 23 -pix_fmt yuv420p -movflags +faststart -an \
       docs/demo.mp4
```

## Sub-projects

| Directory | Role | Stack |
|---|---|---|
| [`server/`](server/) | API + OPDS delivery, SQLite + Active Storage, book scanner, authentication | Rails 8.1 / Ruby 4.0 / Falcon / Thruster / SQLite (FTS5) / SolidQueue |
| [`client/`](client/) | SPA mounted under `/ui`. Book list / detail / search / favorites / settings / Web Reader | Vite + React 19 + TypeScript / Tailwind v4 / shadcn/ui / React Router / TanStack Query / Zustand / foliate-js / PDF.js |

## Features

### Supported formats
- CBZ (ComicInfo.xml supported)
- EPUB
- PDF
- Image directories

### Scanning & metadata
- **EPUB extended metadata**: `dc:subject` is imported as tags, and Calibre's `calibre:series` / `calibre:series_index` as series name and volume number.
- **Series fallback**: Books without series metadata fall back to the parent directory name.
- **Cover image**: The first page is extracted per format and stored via Active Storage.
- **Full-text search**: Title / series / author AND search powered by SQLite FTS5.
- **Taxonomy browsing**: Index pages for series, authors, and tags with thumbnails. Library detail can toggle between book view and series view.
- **Sorting**: Newest, registration date, title, series, and author (ascending / descending).

### Web Reader
- **CBZ / PDF / image directories**: Pages are streamed from the server and rendered client-side. Supports two-page spread / single page, LTR / RTL, and four scale modes.
- **EPUB**: Built on foliate-js. Table of contents, font size, theme (light / dark / sepia), and writing direction (auto / horizontal / vertical) are stored per book.
- **Reading progress**: Page position (CBZ) and CFI + fraction (EPUB) are auto-saved. Progress is reflected as a bar overlaid on the cover, in the "recently read" carousel on the home page, and on the book detail page.
- **Hover-revealed scrubber**: Pulled up from the bottom edge to jump directly to any page. CBZ shows a thumbnail at the hover position, EPUB shows the corresponding chapter label.
- **Keyboard navigation + hints**: Arrows / Space / Backspace / Esc, plus `2` to toggle spread on CBZ and `Shift + Arrow` to advance by one page. `?` shows the shortcut list.
- **Click zones & hover feedback**: Only the left and right 12% are clickable (to avoid blocking text selection in the middle), with hover tint.

### Delivery & integrations
- **OPDS / OPDS-PSE**: Delivered as Atom feeds to other reader apps.
- **Authentication**: Cookie sessions (for UI) and Bearer tokens (for OPDS / Reader) coexist.
- **Mobile support**: Works on viewports starting from 390px.

## Development

### 1. System requirements

- Ruby 4.0.3+
- Node.js 22+ / npm
- SQLite 3 (build with FTS5 enabled)

### 2. Install dependencies

```sh
(cd server && bundle install && bin/rails db:setup)
(cd client && npm install)
```

### 3. Start the dev servers together

```sh
cd server
bin/dev          # Starts web (Falcon, :3000) and client (Vite, :5173) together via foreman
```

## Docker image

See [Dockerfile](./Dockerfile).

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

- Thruster listens on port **8237** and proxies to the internal Falcon (`TARGET_PORT=3000`).
- The **`/config` volume** holds the SQLite databases (primary / cache / queue / cable) and the Active Storage cover files.
- Mount your actual library (CBZ / EPUB / PDF, etc.) as a separate volume and register its path as a library from Bookwall's settings screen.

## Architecture overview

```
                   ┌──────────────────────────┐
                   │  Browser / OPDS Reader   │
                   └────────────┬─────────────┘
                                │ HTTP/1.1, HTTP/2 (Thruster)
                                ▼
                   ┌──────────────────────────┐
                   │  Thruster (port 8237)    │  ← Docker only
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

In addition, `/` redirects to `/ui/`, and Rails' built-in `/up` health check endpoint is routed. The `Scheduled*` jobs (ScheduledLibraryScanJob / ScheduledCleanupJob) are kicked off daily by SolidQueue per `config/recurring.yml`.

Book files are stored in `Book.file_path` as paths relative to the library root, and resolved at runtime as `library.path + file_path`.

## Repository layout

```
bookwall/
├── README.md             # ← this file
├── README-ja.md          # Japanese translation
├── LICENSE               # MIT
├── Dockerfile            # multi-stage (client build → server image)
├── .dockerignore
├── .gitignore
├── CLAUDE.md             # Project requirements (for Claude Code)
├── docs/                 # demo.mp4 (Playwright guided-tour recording, H.264)
├── server/               # Rails 8.1 API + OPDS. See server/README.md
└── client/               # Vite + React + TS SPA. See client/README.md
```

The provenance and licenses of the test book fixtures under `server/spec/fixtures/files/` (CBZ / EPUB / PDF / image directories) are documented in [`server/spec/fixtures/files/SOURCES.md`](server/spec/fixtures/files/SOURCES.md).

## License

MIT License.
