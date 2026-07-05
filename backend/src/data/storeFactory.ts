import { config } from "../config.js";
import { MemoryStore } from "./memoryStore.js";
import { SupabaseStore } from "./supabaseStore.js";
import type { DataStore } from "./store.js";

let singleton: DataStore | undefined;

/**
 * Process-wide data store. Uses Supabase/Postgres when DATA_STORE=supabase (or
 * postgres) and a connection string is present; otherwise an in-memory store so
 * the service runs with zero external dependencies.
 */
export function getDataStore(): DataStore {
  if (!singleton) {
    const useSupabase =
      (config.dataStore === "supabase" || config.dataStore === "postgres") &&
      Boolean(config.supabaseDbUrl);
    singleton = useSupabase ? new SupabaseStore(config.supabaseDbUrl) : new MemoryStore();
  }
  return singleton;
}

export type { DataStore } from "./store.js";
