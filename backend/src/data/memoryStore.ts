import type {
  AiRecommendation,
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  Game,
  Injury,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  RecommendationKind,
  Team,
} from "./models.js";
import type {
  DataStore,
  GameFilter,
  InjuryFilter,
  PlayerFilter,
} from "./store.js";

const key3 = (id: string, season: number, week: number): string => `${id}:${season}:${week}`;

/** Zero-dependency in-memory store. Default store for dev / CI / tests. */
export class MemoryStore implements DataStore {
  private teams = new Map<string, Team>();
  private players = new Map<string, Player>();
  private games = new Map<string, Game>();
  private weekly = new Map<string, PlayerWeeklyStat>();
  private projections = new Map<string, PlayerProjection>();
  private injuries = new Map<string, Injury>();
  private leagues = new Map<string, FantasyLeague>();
  private rosters = new Map<string, FantasyRoster>();
  private matchups = new Map<string, FantasyMatchup>();
  private recommendations: AiRecommendation[] = [];

  async migrate(): Promise<void> {}
  async close(): Promise<void> {}

  async upsertTeams(rows: Team[]): Promise<number> {
    for (const t of rows) this.teams.set(t.teamId, { ...t });
    return rows.length;
  }
  async getTeams(): Promise<Team[]> {
    return [...this.teams.values()].map((t) => ({ ...t }));
  }
  async getTeam(teamId: string): Promise<Team | undefined> {
    const t = this.teams.get(teamId);
    return t ? { ...t } : undefined;
  }

  async upsertPlayers(rows: Player[]): Promise<number> {
    for (const p of rows) this.players.set(p.playerId, { ...p });
    return rows.length;
  }
  async getPlayers(filter: PlayerFilter): Promise<Player[]> {
    let rows = [...this.players.values()];
    if (filter.position) rows = rows.filter((p) => p.position === filter.position);
    if (filter.team) rows = rows.filter((p) => p.team === filter.team);
    if (filter.search) {
      const q = filter.search.toLowerCase();
      rows = rows.filter((p) => p.fullName.toLowerCase().includes(q));
    }
    rows.sort((a, b) => a.fullName.localeCompare(b.fullName));
    if (filter.limit !== undefined) rows = rows.slice(0, filter.limit);
    return rows.map((p) => ({ ...p }));
  }
  async getPlayer(playerId: string): Promise<Player | undefined> {
    const p = this.players.get(playerId);
    return p ? { ...p } : undefined;
  }

  async upsertGames(rows: Game[]): Promise<number> {
    for (const g of rows) this.games.set(g.gameId, { ...g });
    return rows.length;
  }
  async getGames(filter: GameFilter): Promise<Game[]> {
    let rows = [...this.games.values()];
    if (filter.season !== undefined) rows = rows.filter((g) => g.season === filter.season);
    if (filter.week !== undefined) rows = rows.filter((g) => g.week === filter.week);
    if (filter.status) rows = rows.filter((g) => g.status === filter.status);
    if (filter.team) {
      rows = rows.filter((g) => g.homeTeam === filter.team || g.awayTeam === filter.team);
    }
    rows.sort((a, b) => (a.kickoff ?? "").localeCompare(b.kickoff ?? ""));
    if (filter.limit !== undefined) rows = rows.slice(0, filter.limit);
    return rows.map((g) => ({ ...g }));
  }
  async getGame(gameId: string): Promise<Game | undefined> {
    const g = this.games.get(gameId);
    return g ? { ...g } : undefined;
  }

  async upsertWeeklyStats(rows: PlayerWeeklyStat[]): Promise<number> {
    for (const s of rows) this.weekly.set(key3(s.playerId, s.season, s.week), { ...s });
    return rows.length;
  }
  async getPlayerWeeklyStats(
    playerId: string,
    season?: number,
    week?: number,
  ): Promise<PlayerWeeklyStat[]> {
    let rows = [...this.weekly.values()].filter((s) => s.playerId === playerId);
    if (season !== undefined) rows = rows.filter((s) => s.season === season);
    if (week !== undefined) rows = rows.filter((s) => s.week === week);
    rows.sort((a, b) => b.season - a.season || b.week - a.week);
    return rows.map((s) => ({ ...s }));
  }

  async upsertProjections(rows: PlayerProjection[]): Promise<number> {
    for (const p of rows) this.projections.set(key3(p.playerId, p.season, p.week), { ...p });
    return rows.length;
  }
  async getPlayerProjections(
    playerId: string,
    season?: number,
    week?: number,
  ): Promise<PlayerProjection[]> {
    let rows = [...this.projections.values()].filter((p) => p.playerId === playerId);
    if (season !== undefined) rows = rows.filter((p) => p.season === season);
    if (week !== undefined) rows = rows.filter((p) => p.week === week);
    rows.sort((a, b) => b.season - a.season || b.week - a.week);
    return rows.map((p) => ({ ...p }));
  }

  async upsertInjuries(rows: Injury[]): Promise<number> {
    for (const i of rows) this.injuries.set(key3(i.playerId, i.season, i.week), { ...i });
    return rows.length;
  }
  async getPlayerInjury(playerId: string): Promise<Injury | undefined> {
    const rows = [...this.injuries.values()]
      .filter((i) => i.playerId === playerId)
      .sort((a, b) => b.season - a.season || b.week - a.week);
    const latest = rows[0];
    return latest ? { ...latest } : undefined;
  }
  async getInjuries(filter: InjuryFilter): Promise<Injury[]> {
    let rows = [...this.injuries.values()];
    if (filter.season !== undefined) rows = rows.filter((i) => i.season === filter.season);
    if (filter.week !== undefined) rows = rows.filter((i) => i.week === filter.week);
    if (filter.team) {
      const teamPlayers = new Set(
        [...this.players.values()].filter((p) => p.team === filter.team).map((p) => p.playerId),
      );
      rows = rows.filter((i) => teamPlayers.has(i.playerId));
    }
    return rows.map((i) => ({ ...i }));
  }

  async upsertLeague(row: FantasyLeague): Promise<void> {
    this.leagues.set(row.leagueId, { ...row });
  }
  async getLeague(leagueId: string): Promise<FantasyLeague | undefined> {
    const l = this.leagues.get(leagueId);
    return l ? { ...l } : undefined;
  }

  async upsertRosters(rows: FantasyRoster[]): Promise<number> {
    for (const r of rows) this.rosters.set(`${r.leagueId}:${r.rosterId}`, { ...r });
    return rows.length;
  }
  async getLeagueRosters(leagueId: string): Promise<FantasyRoster[]> {
    return [...this.rosters.values()]
      .filter((r) => r.leagueId === leagueId)
      .map((r) => ({ ...r }));
  }
  async getRoster(leagueId: string, rosterId: string): Promise<FantasyRoster | undefined> {
    const r = this.rosters.get(`${leagueId}:${rosterId}`);
    return r ? { ...r } : undefined;
  }

  async upsertMatchups(rows: FantasyMatchup[]): Promise<number> {
    for (const m of rows) {
      this.matchups.set(`${m.leagueId}:${m.week}:${m.rosterId}`, { ...m });
    }
    return rows.length;
  }
  async getLeagueMatchups(leagueId: string, week?: number): Promise<FantasyMatchup[]> {
    let rows = [...this.matchups.values()].filter((m) => m.leagueId === leagueId);
    if (week !== undefined) rows = rows.filter((m) => m.week === week);
    rows.sort((a, b) => a.week - b.week || a.matchupId.localeCompare(b.matchupId));
    return rows.map((m) => ({ ...m }));
  }

  async insertRecommendation(rec: AiRecommendation): Promise<void> {
    this.recommendations.unshift({ ...rec });
  }
  async getRecommendations(filter: {
    leagueId?: string;
    kind?: RecommendationKind;
    limit?: number;
  }): Promise<AiRecommendation[]> {
    let rows = [...this.recommendations];
    if (filter.leagueId) rows = rows.filter((r) => r.leagueId === filter.leagueId);
    if (filter.kind) rows = rows.filter((r) => r.kind === filter.kind);
    if (filter.limit !== undefined) rows = rows.slice(0, filter.limit);
    return rows.map((r) => ({ ...r }));
  }
}
