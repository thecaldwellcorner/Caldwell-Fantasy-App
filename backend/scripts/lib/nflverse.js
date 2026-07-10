// nflverse provider adapter.
//
// Uses nflverse's PUBLIC, downloadable datasets (CSV release assets and the
// nfldata schedule file). This is licensed open data — NOT web scraping of
// ESPN/NFL.com/Yahoo/FantasyPros/PFF. All source URLs are centralized here so a
// future provider can be swapped in without touching the import scripts.
//
// nflverse occasionally renames release assets between seasons, so each fetch
// tries a small list of known-good URL patterns and uses the first that works.

import { parseCSV } from "./csv.js";

export const SOURCE = "nflverse";

const RELEASE = "https://github.com/nflverse/nflverse-data/releases/download";
const NFLDATA = "https://raw.githubusercontent.com/nflverse/nfldata/master/data";

async function fetchFirstCSV(urls) {
  const errors = [];
  for (const url of urls) {
    try {
      const res = await fetch(url);
      if (res.ok) {
        return parseCSV(await res.text());
      }
      errors.push(`${res.status} ${res.statusText} @ ${url}`);
    } catch (err) {
      errors.push(`${err.message} @ ${url}`);
    }
  }
  throw new Error(`nflverse fetch failed. Tried:\n  ${errors.join("\n  ")}`);
}

/** Full-league schedule for a season (kickoffs, teams, scores, venue). */
export async function fetchSchedule(season) {
  const rows = await fetchFirstCSV([`${NFLDATA}/games.csv`]);
  return rows.filter((r) => Number(r.season) === Number(season));
}

/**
 * Weekly player box-score stats for a season. The same file also carries the
 * advanced usage columns (target_share, air_yards_share) used by advanced stats.
 */
export async function fetchWeeklyStats(season) {
  return fetchFirstCSV([
    `${RELEASE}/player_stats/player_stats_${season}.csv`,
    `${RELEASE}/player_stats/stats_player_week_${season}.csv`,
    `${RELEASE}/stats_player/stats_player_week_${season}.csv`,
  ]);
}

/** Advanced usage source (currently the same weekly player_stats file). */
export async function fetchAdvancedStats(season) {
  return fetchWeeklyStats(season);
}
