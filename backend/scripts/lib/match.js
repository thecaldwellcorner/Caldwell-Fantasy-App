// Matches provider (nflverse) player rows to our Supabase `players` table.
//
// nflverse identifies players by GSIS id + name; our players table is keyed by
// sleeper_id. We don't have a shared id, so we match on normalized name (+
// position, then team to disambiguate). Unmatched players are reported, never
// silently dropped.

const SUFFIXES = new Set(["jr", "sr", "ii", "iii", "iv", "v"]);

export function normalizeName(name) {
  if (!name) return "";
  return String(name)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .split(/\s+/)
    .filter((part) => !SUFFIXES.has(part.replace(/[^a-z]/g, "")))
    .join(" ")
    .replace(/[^a-z]/g, "");
}

/**
 * Load every player from Supabase (paginated) and build lookup indexes.
 * Returns { byNamePos: Map, byName: Map } where values are arrays of players.
 */
export async function buildPlayerIndex(supabase) {
  const byNamePos = new Map();
  const byName = new Map();
  const pageSize = 1000;
  let from = 0;

  for (;;) {
    const { data, error } = await supabase
      .from("players")
      .select("id,sleeper_id,full_name,position,team")
      .range(from, from + pageSize - 1);
    if (error) throw new Error(`Failed to load players: ${error.message}`);
    if (!data || data.length === 0) break;

    for (const p of data) {
      const nn = normalizeName(p.full_name);
      if (!nn) continue;
      byName.set(nn, (byName.get(nn) || []).concat(p));
      const key = `${nn}|${(p.position || "").toUpperCase()}`;
      byNamePos.set(key, (byNamePos.get(key) || []).concat(p));
    }

    if (data.length < pageSize) break;
    from += pageSize;
  }
  return { byNamePos, byName };
}

/**
 * Resolve a provider row to a players.id (uuid). Returns the matched player or
 * null. Strategy: name+position, disambiguate by team, then fall back to a
 * unique name-only match.
 */
export function matchPlayer(index, { name, position, team }) {
  const nn = normalizeName(name);
  if (!nn) return null;

  const posKey = `${nn}|${(position || "").toUpperCase()}`;
  let candidates = index.byNamePos.get(posKey) || [];

  if (candidates.length === 1) return candidates[0];
  if (candidates.length > 1) {
    const t = (team || "").toUpperCase();
    const byTeam = candidates.filter((c) => (c.team || "").toUpperCase() === t);
    return byTeam.length === 1 ? byTeam[0] : null; // ambiguous
  }

  candidates = index.byName.get(nn) || [];
  return candidates.length === 1 ? candidates[0] : null;
}
