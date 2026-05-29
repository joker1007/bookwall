import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { ScheduledTaskSettings } from "@/types/api";

const KEY = ["scheduled_task_settings"] as const;

export function useScheduledTaskSettings() {
  return useQuery<ScheduledTaskSettings>({
    queryKey: KEY,
    queryFn: () => api<ScheduledTaskSettings>("/api/scheduled_task_settings"),
  });
}

export function useUpdateScheduledTaskSettings() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: Partial<ScheduledTaskSettings>) =>
      api<ScheduledTaskSettings>("/api/scheduled_task_settings", {
        method: "PATCH",
        body: payload,
      }),
    onSuccess: (data) => {
      queryClient.setQueryData<ScheduledTaskSettings>(KEY, data);
    },
  });
}
