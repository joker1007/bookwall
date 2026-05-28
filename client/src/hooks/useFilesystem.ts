import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

export interface FilesystemEntry {
  name: string;
  path: string;
}

export interface FilesystemBrowseResponse {
  path: string;
  parent: string | null;
  exists: boolean;
  readable: boolean;
  entries: FilesystemEntry[];
}

export function useFilesystemBrowse(path: string | null, enabled: boolean) {
  return useQuery<FilesystemBrowseResponse>({
    queryKey: ["filesystem", "browse", path ?? ""],
    enabled,
    queryFn: () =>
      api<FilesystemBrowseResponse>("/api/filesystem/browse", {
        params: path ? { path } : undefined,
      }),
  });
}
