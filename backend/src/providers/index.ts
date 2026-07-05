import { config } from "../config.js";
import { MockLeagueProvider } from "./mockLeagueProvider.js";
import { MockStatsProvider } from "./mockStatsProvider.js";
import { SleeperLeagueProvider } from "./sleeperLeagueProvider.js";
import { SportsDataIoProvider } from "./sportsDataIoProvider.js";
import type { LeagueProvider, StatsProvider } from "./types.js";

/**
 * Selects the stats provider from config. A licensed provider is used only when
 * it is fully configured (API key present); otherwise we fall back to the mock
 * adapter so the service always works. Keys live in the backend env only.
 */
export function getStatsProvider(): StatsProvider {
  switch (config.statsProvider) {
    case "sportsdataio": {
      const p = new SportsDataIoProvider({
        apiKey: config.sportsDataIoApiKey,
        baseUrl: config.sportsDataIoBase,
      });
      return p.isConfigured() ? p : new MockStatsProvider();
    }
    case "mock":
    default:
      return new MockStatsProvider();
  }
}

/** Selects the fantasy league provider (Sleeper vs. mock) from config. */
export function getLeagueProvider(): LeagueProvider {
  switch (config.leagueProvider) {
    case "sleeper": {
      const p = new SleeperLeagueProvider(config.sleeperApiBase);
      return p.isConfigured() ? p : new MockLeagueProvider();
    }
    case "mock":
    default:
      return new MockLeagueProvider();
  }
}

export type { LeagueProvider, StatsProvider } from "./types.js";
