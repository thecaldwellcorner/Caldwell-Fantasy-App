import type {
  Game,
  Injury,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  Team,
} from "../data/models.js";
import type { ProviderContext, StatsProvider } from "./types.js";

export interface PaidProviderOptions {
  apiKey: string | undefined;
  baseUrl: string;
}

/**
 * Template adapter for a licensed NFL stats provider (SportsDataIO shown; the
 * same shape applies to MySportsFeeds / Sportradar). This is where a paid feed
 * plugs in later WITHOUT changing the store, sync service, API, or the app.
 *
 * The API key is read from the backend environment only and is NEVER sent to or
 * exposed in the iOS/Xcode app — the app only ever calls our own endpoints.
 *
 * Each `fetch*` method should:
 *   1. call the vendor endpoint with `this.opts.apiKey`,
 *   2. map the raw payload into our normalized models, and
 *   3. stamp `meta` with `source: "sportsdataio"`, `sourceUpdatedAt` (the
 *      vendor's as-of timestamp) and `fetchedAt` (now).
 *
 * Until credentials + a mapping are wired, it reports `isConfigured() === false`
 * so the provider factory falls back to the mock adapter and the app keeps
 * working. Left intentionally unimplemented to avoid guessing a vendor schema.
 */
export class SportsDataIoProvider implements StatsProvider {
  readonly sourceLabel = "sportsdataio" as const;

  constructor(private readonly opts: PaidProviderOptions) {}

  isConfigured(): boolean {
    return Boolean(this.opts.apiKey);
  }

  private notImplemented(method: string): never {
    throw new Error(
      `SportsDataIoProvider.${method} is not implemented yet. Add the vendor mapping ` +
        `and set SPORTSDATAIO_API_KEY, then this adapter will be selected automatically.`,
    );
  }

  async fetchTeams(_ctx: ProviderContext): Promise<Team[]> {
    return this.notImplemented("fetchTeams");
  }
  async fetchPlayers(_ctx: ProviderContext): Promise<Player[]> {
    return this.notImplemented("fetchPlayers");
  }
  async fetchGames(_ctx: ProviderContext): Promise<Game[]> {
    return this.notImplemented("fetchGames");
  }
  async fetchWeeklyStats(_ctx: ProviderContext): Promise<PlayerWeeklyStat[]> {
    return this.notImplemented("fetchWeeklyStats");
  }
  async fetchProjections(_ctx: ProviderContext): Promise<PlayerProjection[]> {
    return this.notImplemented("fetchProjections");
  }
  async fetchInjuries(_ctx: ProviderContext): Promise<Injury[]> {
    return this.notImplemented("fetchInjuries");
  }
}
