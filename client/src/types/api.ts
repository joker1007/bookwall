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
  file_hash: string | null;
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
}

export interface Library {
  id: number;
  name: string;
  path: string;
  last_scanned_at: string | null;
  created_at: string;
  updated_at: string;
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
  sample_cover_thumb_url: string | null;
  created_at: string;
  updated_at: string;
}

export interface ApiToken {
  id: number;
  name: string;
  token: string;
  last_used_at: string | null;
  expires_at: string | null;
  created_at: string;
}

// Issued tokens are the same shape; kept as a separate alias for clarity
// at call sites where it's explicitly the plaintext-bearing record.
export type IssuedApiToken = ApiToken;
