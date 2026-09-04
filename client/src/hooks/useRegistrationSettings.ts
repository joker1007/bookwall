import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { RegistrationSettings } from "@/types/api";

export const REGISTRATION_SETTINGS_KEY = ["registration_settings"] as const;

export function useRegistrationSettings() {
  return useQuery<RegistrationSettings>({
    queryKey: REGISTRATION_SETTINGS_KEY,
    queryFn: () => api<RegistrationSettings>("/api/registration_settings"),
  });
}

export function useUpdateRegistrationSettings() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (payload: Partial<Pick<RegistrationSettings, "public_registration_enabled">>) =>
      api<RegistrationSettings>("/api/registration_settings", {
        method: "PATCH",
        body: payload,
      }),
    onSuccess: (data) => {
      queryClient.setQueryData<RegistrationSettings>(REGISTRATION_SETTINGS_KEY, data);
    },
  });
}
