import { createClient } from "@supabase/supabase-js";

/**
 * Server-side Supabase client for import scripts. Uses the SERVICE ROLE key,
 * which must ONLY ever run on the server — never in the iOS app.
 *
 * Returns null when credentials are absent (so `--dry-run` can still fetch and
 * report without requiring keys). Pass `{ required: true }` to throw instead.
 */
export function getSupabase({ required = true } = {}) {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    if (required) {
      throw new Error(
        "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Set them in .env (server-side only).",
      );
    }
    return null;
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
