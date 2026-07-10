// Projections provider adapter interface.
//
// Projections are NEVER derived from scraping or invented. Until a licensed
// projections API is configured, this returns null and the import script does
// nothing. To wire a licensed provider later, implement `fetchProjections` to
// return rows shaped like:
//   { providerPlayerId, name, position, team, season, week,
//     projectedPointsPpr, projectedPointsHalfPpr, projectedPointsStandard,
//     floor, ceiling, confidence, modelVersion }
// and map them to players via lib/match.js in importProjections.js.

export function getProjectionsProvider() {
  const apiKey = process.env.PROJECTIONS_API_KEY;
  const source = process.env.PROJECTIONS_SOURCE;
  if (!apiKey || !source) return null;

  return {
    source,
    async fetchProjections(/* season, week */) {
      throw new Error(
        `Projections provider "${source}" is configured but its adapter isn't implemented yet. ` +
          "Implement fetchProjections() before enabling this import.",
      );
    },
  };
}
