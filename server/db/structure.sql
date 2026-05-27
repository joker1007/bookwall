CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='Bookwall'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email_address" varchar NOT NULL, "password_digest" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "ip_address" varchar, "user_agent" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "api_tokens" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "name" varchar NOT NULL, "token_digest" varchar NOT NULL, "token" varchar, "last_used_at" datetime(6), "expires_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_f16b5e0447"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_api_tokens_on_user_id" ON "api_tokens" ("user_id") /*application='Bookwall'*/;
CREATE UNIQUE INDEX "index_api_tokens_on_token_digest" ON "api_tokens" ("token_digest") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "libraries" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "path" varchar NOT NULL, "last_scanned_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_libraries_on_name" ON "libraries" ("name") /*application='Bookwall'*/;
CREATE UNIQUE INDEX "index_libraries_on_path" ON "libraries" ("path") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "series" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "library_id" integer NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c0fe7a0cad"
FOREIGN KEY ("library_id")
  REFERENCES "libraries" ("id")
);
CREATE INDEX "index_series_on_library_id" ON "series" ("library_id") /*application='Bookwall'*/;
CREATE UNIQUE INDEX "index_series_on_library_id_and_name" ON "series" ("library_id", "name") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "authors" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_authors_on_name" ON "authors" ("name") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_tags_on_name" ON "tags" ("name") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "book_authors" ("book_id" integer NOT NULL, "author_id" integer NOT NULL, PRIMARY KEY ("book_id", "author_id"), CONSTRAINT "fk_rails_b23f3934c1"
FOREIGN KEY ("book_id")
  REFERENCES "books" ("id")
, CONSTRAINT "fk_rails_0c0759568d"
FOREIGN KEY ("author_id")
  REFERENCES "authors" ("id")
);
CREATE INDEX "index_book_authors_on_book_id" ON "book_authors" ("book_id") /*application='Bookwall'*/;
CREATE INDEX "index_book_authors_on_author_id" ON "book_authors" ("author_id") /*application='Bookwall'*/;
CREATE INDEX "index_book_authors_on_author_id_only" ON "book_authors" ("author_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "book_tags" ("book_id" integer NOT NULL, "tag_id" integer NOT NULL, PRIMARY KEY ("book_id", "tag_id"), CONSTRAINT "fk_rails_a7d4b3652c"
FOREIGN KEY ("book_id")
  REFERENCES "books" ("id")
, CONSTRAINT "fk_rails_e6b12abac4"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
);
CREATE INDEX "index_book_tags_on_book_id" ON "book_tags" ("book_id") /*application='Bookwall'*/;
CREATE INDEX "index_book_tags_on_tag_id" ON "book_tags" ("tag_id") /*application='Bookwall'*/;
CREATE INDEX "index_book_tags_on_tag_id_only" ON "book_tags" ("tag_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "favorites" ("user_id" integer NOT NULL, "book_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, PRIMARY KEY ("user_id", "book_id"), CONSTRAINT "fk_rails_d15744e438"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_24f323fe32"
FOREIGN KEY ("book_id")
  REFERENCES "books" ("id")
);
CREATE INDEX "index_favorites_on_user_id" ON "favorites" ("user_id") /*application='Bookwall'*/;
CREATE INDEX "index_favorites_on_book_id" ON "favorites" ("book_id") /*application='Bookwall'*/;
CREATE INDEX "index_favorites_on_book_id_only" ON "favorites" ("book_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "scan_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "library_id" integer NOT NULL, "started_at" datetime(6) NOT NULL, "finished_at" datetime(6), "status" integer DEFAULT 0 NOT NULL, "found_count" integer DEFAULT 0 NOT NULL, "added_count" integer DEFAULT 0 NOT NULL, "updated_count" integer DEFAULT 0 NOT NULL, "removed_count" integer DEFAULT 0 NOT NULL, "error_message" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_f40fe8dfc6"
FOREIGN KEY ("library_id")
  REFERENCES "libraries" ("id")
);
CREATE INDEX "index_scan_logs_on_library_id" ON "scan_logs" ("library_id") /*application='Bookwall'*/;
CREATE VIRTUAL TABLE books_fts USING fts5(
  title,
  series_name,
  authors,
  tokenize='unicode61 remove_diacritics 2'
)
/* books_fts(title,series_name,authors) */;
CREATE TABLE IF NOT EXISTS 'books_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'books_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'books_fts_content'(id INTEGER PRIMARY KEY, c0, c1, c2);
CREATE TABLE IF NOT EXISTS 'books_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'books_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "reading_progresses" ("user_id" integer NOT NULL, "book_id" integer NOT NULL, "current_page" integer DEFAULT 0 NOT NULL, "last_read_at" datetime(6) NOT NULL, "settings_json" text, "epub_cfi" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "progress_fraction" float, PRIMARY KEY ("user_id", "book_id"), CONSTRAINT "fk_rails_063fbcdc58"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_57da0b7b28"
FOREIGN KEY ("book_id")
  REFERENCES "books" ("id")
);
CREATE INDEX "index_reading_progresses_on_user_id" ON "reading_progresses" ("user_id") /*application='Bookwall'*/;
CREATE INDEX "index_reading_progresses_on_book_id" ON "reading_progresses" ("book_id") /*application='Bookwall'*/;
CREATE INDEX "index_reading_progresses_on_book_id_only" ON "reading_progresses" ("book_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "user_preferences" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "reader_spread" boolean, "reader_direction" varchar, "reader_scale" varchar, "reader_preload_ahead" integer, "reader_font_size" integer, "reader_theme" varchar, "reader_writing_mode" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_a69bfcfd81"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE UNIQUE INDEX "index_user_preferences_on_user_id" ON "user_preferences" ("user_id") /*application='Bookwall'*/;
CREATE TABLE IF NOT EXISTS "books" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "library_id" integer NOT NULL, "series_id" integer, "title" varchar NOT NULL, "volume" integer, "file_path" varchar NOT NULL, "file_format" integer NOT NULL, "file_size" bigint DEFAULT 0 NOT NULL, "page_count" integer, "published_at" date, "added_at" datetime(6) NOT NULL, "scanned_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1c0d164eeb"
FOREIGN KEY ("series_id")
  REFERENCES "series" ("id")
, CONSTRAINT "fk_rails_9bb3dacd9b"
FOREIGN KEY ("library_id")
  REFERENCES "libraries" ("id")
);
CREATE INDEX "index_books_on_library_id" ON "books" ("library_id");
CREATE INDEX "index_books_on_series_id" ON "books" ("series_id");
CREATE UNIQUE INDEX "index_books_on_library_id_and_file_path" ON "books" ("library_id", "file_path");
CREATE INDEX "index_books_on_added_at" ON "books" ("added_at");
CREATE INDEX "index_books_on_library_id_and_series_id_and_volume" ON "books" ("library_id", "series_id", "volume");
INSERT INTO "schema_migrations" (version) VALUES
('20260528140000'),
('20260528063244'),
('20260528043120'),
('20260528000000'),
('20260527000009'),
('20260527000008'),
('20260527000007'),
('20260527000006'),
('20260527000005'),
('20260527000004'),
('20260527000003'),
('20260527000002'),
('20260527000001'),
('20260527000000'),
('20260526201700'),
('20260526201635'),
('20260526201634'),
('20260526201430');

