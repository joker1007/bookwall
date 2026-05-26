import { useSessionBootstrap } from "@/hooks/useAuth";

/**
 * Mounted once near the router root so that `/api/session` is fetched on
 * boot and the result rehydrates the auth store. Doesn't render anything.
 */
export function SessionBootstrap() {
  useSessionBootstrap();
  return null;
}
