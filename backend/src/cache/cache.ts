/**
 * Minimal cache abstraction. Uses an in-memory TTL cache by default; this is
 * where a Redis-backed implementation would plug in (PRD tech stack lists Redis
 * for high-speed caching). The rest of the app depends only on this interface.
 */
export interface Cache {
  get<T>(key: string): Promise<T | undefined>;
  set<T>(key: string, value: T, ttlSeconds: number): Promise<void>;
  del(key: string): Promise<void>;
}

interface Entry {
  value: unknown;
  expiresAt: number;
}

export class InMemoryCache implements Cache {
  private store = new Map<string, Entry>();

  async get<T>(key: string): Promise<T | undefined> {
    const entry = this.store.get(key);
    if (!entry) return undefined;
    if (Date.now() > entry.expiresAt) {
      this.store.delete(key);
      return undefined;
    }
    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlSeconds: number): Promise<void> {
    this.store.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
  }

  async del(key: string): Promise<void> {
    this.store.delete(key);
  }
}

let cacheSingleton: Cache | undefined;

/** Returns the process-wide cache. Swap here to wire Redis when REDIS_URL is set. */
export function getCache(): Cache {
  if (!cacheSingleton) {
    cacheSingleton = new InMemoryCache();
  }
  return cacheSingleton;
}
