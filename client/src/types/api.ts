export interface User {
  id: number;
  email_address: string;
}

export interface Pagination {
  page: number;
  pages: number;
  count: number;
}

export interface CoverInfo {
  url: string;
  thumb_url: string;
}

export interface Book {
  id: number;
  title: string;
  volume: number | null;
  file_format: "cbz" | "epub" | "pdf" | "image_dir";
  file_path: string;
  file_size: number;
  page_count: number | null;
  published_at: string | null;
  added_at: string;
  scanned_at: string | null;
  library_id: number;
  series_id: number | null;
  series_name: string | null;
  authors: { id: number; name: string }[];
  tags: { id: number; name: string }[];
  favorited: boolean;
  cover: CoverInfo | null;
  // Null until the user opens the book. `fraction` stays null for EPUB
  // (no precise position yet) even after last_read_at is set.
  reading_progress: {
    fraction: number | null;
    current_page: number;
    last_read_at: string | null;
  } | null;
}

export interface Library {
  id: number;
  name: string;
  path: string;
  last_scanned_at: string | null;
  created_at: string;
  updated_at: string;
  owner_id: number;
  can_manage: boolean;
  // Only populated for the owner; [] otherwise.
  shared_user_ids: number[];
  auto_scan_enabled: boolean;
}

export interface ScheduledTaskSettings {
  daily_scan_enabled: boolean;
  cleanup_enabled: boolean;
}

export interface RegistrationSettings {
  public_registration_enabled: boolean;
  registration_open: boolean;
}

export type ScanStatus = "pending" | "running" | "succeeded" | "failed";

export interface ScanLog {
  id: number;
  library_id: number;
  status: ScanStatus;
  started_at: string;
  finished_at: string | null;
  found_count: number;
  added_count: number;
  updated_count: number;
  removed_count: number;
  // Non-null only while status === "running".
  processed_count: number | null;
  error_message: string | null;
}

export interface Series {
  id: number;
  name: string;
  library_id: number;
  book_count: number;
  sample_cover_thumb_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Author {
  id: number;
  name: string;
  book_count: number;
  sample_cover_thumb_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface Tag {
  id: number;
  name: string;
  book_count: number;
  created_at: string;
  updated_at: string;
}

export interface Collection {
  id: number;
  name: string;
  book_count: number;
  sample_cover_thumb_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface CollectionsListResponse {
  collections: Collection[];
  pagination: Pagination;
}

export interface ApiToken {
  id: number;
  name: string;
  token: string;
  last_used_at: string | null;
  expires_at: string | null;
  created_at: string;
}

// Same shape; aliased to mark the plaintext-bearing record at call sites.
export type IssuedApiToken = ApiToken;

export const READER_SCALE_VALUES = [
  "fit",
  "fit_height",
  "fit_width",
  "original",
] as const;
export type ReaderScale = (typeof READER_SCALE_VALUES)[number];

export const READER_PRELOAD_AHEAD_OPTIONS = [0, 2, 4, 8] as const;
export const READER_PRELOAD_AHEAD_DEFAULT = 4;

export const READER_THEME_VALUES = ["light", "dark", "sepia"] as const;
export type ReaderTheme = (typeof READER_THEME_VALUES)[number];

export const READER_WRITING_MODE_VALUES = ["auto", "horizontal", "vertical"] as const;
export type ReaderWritingMode = (typeof READER_WRITING_MODE_VALUES)[number];

export const READER_FONT_SIZE_DEFAULT = 100;
export const READER_FONT_SIZE_MIN = 50;
export const READER_FONT_SIZE_MAX = 300;
export const READER_FONT_SIZE_STEP = 10;

export const READER_PROGRESS_DEBOUNCE_MS = 800;

export interface ReaderSettings {
  // CBZ / PDF / image_dir only. direction also flips arrow keys + tap zones.
  spread?: boolean;
  direction?: "ltr" | "rtl";
  scale?: ReaderScale;
  // User-wide default only; per-book settings ignore this field.
  preload_ahead?: number;
  // EPUB only.
  font_size?: number;            // percent, default 100
  theme?: ReaderTheme;
  // "auto" trusts the book's own CSS; "horizontal"/"vertical" force-override.
  // Vertical implies RTL navigation at runtime.
  writing_mode?: ReaderWritingMode;
}

export interface ReadingProgress {
  current_page: number;
  last_read_at: string | null;
  epub_cfi: string | null;
  // EPUB only: 0..1 from foliate's relocate event; null if never opened in foliate.
  progress_fraction: number | null;
  settings: ReaderSettings;
}

export interface UserPreferences {
  reader_defaults: ReaderSettings;
}
