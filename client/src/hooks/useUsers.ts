import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { User } from "@/types/api";

interface UserListResponse {
  users: User[];
}

// Directory of users for the library share picker.
export function useUsers() {
  return useQuery<UserListResponse>({
    queryKey: ["users"],
    queryFn: () => api<UserListResponse>("/api/users"),
    staleTime: 60_000,
  });
}
