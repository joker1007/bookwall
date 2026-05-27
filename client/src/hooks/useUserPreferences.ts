import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ReaderSettings, UserPreferences } from "@/types/api";

const KEY = ["preferences"] as const;

export function useUserPreferences() {
  return useQuery<UserPreferences>({
    queryKey: KEY,
    queryFn: () => api<UserPreferences>("/api/preferences"),
  });
}

export function useUpdateUserPreferences() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: { reader_defaults: ReaderSettings }) =>
      api<UserPreferences>("/api/preferences", {
        method: "PATCH",
        body: payload,
      }),
    onSuccess: (data) => {
      queryClient.setQueryData<UserPreferences>(KEY, data);
    },
  });
}
