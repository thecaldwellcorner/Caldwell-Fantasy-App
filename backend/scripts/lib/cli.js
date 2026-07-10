// Shared CLI helpers: arg parsing (season + dry-run) and a section logger.

export function parseArgs() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run") || process.env.DRY_RUN === "1";

  let season;
  const flagIdx = args.findIndex((a) => a === "--season");
  if (flagIdx >= 0 && args[flagIdx + 1]) season = Number(args[flagIdx + 1]);
  const positional = args.find((a) => /^\d{4}$/.test(a));
  if (season === undefined && positional) season = Number(positional);
  if (season === undefined && process.env.SEASON) season = Number(process.env.SEASON);
  if (season === undefined || !Number.isFinite(season)) season = new Date().getFullYear();

  return { dryRun, season, args };
}

export function makeLogger(prefix) {
  return (message) => console.log(`[${prefix}] ${message}`);
}

/** Print a compact list of unmatched players (capped) so nothing is dropped silently. */
export function reportUnmatched(log, unmatched, cap = 25) {
  if (unmatched.length === 0) return;
  log(`⚠️  ${unmatched.length} player(s) could not be matched to the players table:`);
  for (const u of unmatched.slice(0, cap)) {
    log(`   - ${u.name} (${u.position || "?"}, ${u.team || "?"}, provider_id=${u.providerId || "?"})`);
  }
  if (unmatched.length > cap) log(`   … and ${unmatched.length - cap} more`);
}
