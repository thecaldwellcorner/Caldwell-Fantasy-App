import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import pg from "pg";
import type {
  AiRecommendation,
  DataSource,
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  Game,
  GameStatus,
  Injury,
  InjuryDesignation,
  KeyStat,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  Position,
  RecommendationKind,
  ScoringFormat,
  SeasonType,
  SourceMeta,
  Team,
} from "./models.js";
import type { DataStore, GameFilter, InjuryFilter, PlayerFilter } from "./store.js";

const { Pool } = pg;

const iso = (d: Date | string | null | undefined): string | null => {
  if (d === null || d === undefined) return null;
  return d instanceof Date ? d.toISOString() : new Date(d).toISOString();
};

const num = (v: unknown): number => (v === null || v === undefined ? 0 : Number(v));
const numOrNull = (v: unknown): number | null => (v === null || v === undefined ? null : Number(v));

function metaFrom(r: Record<string, unknown>): SourceMeta {
  return {
    source: (r.source as DataSource) ?? "mock",
    sourceUpdatedAt: iso(r.source_updated_at as Date | null) ?? iso(r.updated_at as Date | null) ?? new Date().toISOString(),
    fetchedAt: iso(r.fetched_at as Date | null) ?? new Date().toISOString(),
  };
}

/**
 * Supabase / PostgreSQL-backed store. Supabase is just managed Postgres, so we
 * connect with the standard `pg` pool via SUPABASE_DB_URL / DATABASE_URL. API
 * keys and the connection string live only in the backend environment.
 */
export class SupabaseStore implements DataStore {
  private pool: pg.Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({
      connectionString,
      // Supabase requires TLS; allow self-signed in managed environments.
      ssl: /supabase|sslmode=require/.test(connectionString) ? { rejectUnauthorized: false } : undefined,
    });
  }

  async migrate(): Promise<void> {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const schemaPath = path.resolve(here, "../../db/supabase_schema.sql");
    const sql = await readFile(schemaPath, "utf8");
    await this.pool.query(sql);
  }

  async close(): Promise<void> {
    await this.pool.end();
  }

  private async batch(sql: string, rows: unknown[][]): Promise<number> {
    if (rows.length === 0) return 0;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      for (const params of rows) await client.query(sql, params);
      await client.query("COMMIT");
      return rows.length;
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  // ---- teams ----
  async upsertTeams(rows: Team[]): Promise<number> {
    return this.batch(
      `INSERT INTO teams (team_id, name, abbreviation, conference, division, bye_week, logo_url,
         source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now())
       ON CONFLICT (team_id) DO UPDATE SET
         name=EXCLUDED.name, abbreviation=EXCLUDED.abbreviation, conference=EXCLUDED.conference,
         division=EXCLUDED.division, bye_week=EXCLUDED.bye_week, logo_url=EXCLUDED.logo_url,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((t) => [
        t.teamId, t.name, t.abbreviation, t.conference, t.division, t.byeWeek, t.logoUrl,
        t.meta.source, t.meta.sourceUpdatedAt, t.meta.fetchedAt,
      ]),
    );
  }
  async getTeams(): Promise<Team[]> {
    const { rows } = await this.pool.query("SELECT * FROM teams ORDER BY team_id");
    return rows.map((r) => this.rowToTeam(r));
  }
  async getTeam(teamId: string): Promise<Team | undefined> {
    const { rows } = await this.pool.query("SELECT * FROM teams WHERE team_id=$1", [teamId]);
    return rows[0] ? this.rowToTeam(rows[0]) : undefined;
  }
  private rowToTeam(r: Record<string, unknown>): Team {
    return {
      teamId: r.team_id as string,
      name: r.name as string,
      abbreviation: r.abbreviation as string,
      conference: (r.conference as string) ?? null,
      division: (r.division as string) ?? null,
      byeWeek: numOrNull(r.bye_week),
      logoUrl: (r.logo_url as string) ?? null,
      meta: metaFrom(r),
    };
  }

  // ---- players ----
  async upsertPlayers(rows: Player[]): Promise<number> {
    return this.batch(
      `INSERT INTO players (player_id, full_name, first_name, last_name, position, team,
         jersey_number, age, height_inches, weight_lbs, college, status, headshot_url,
         source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16, now())
       ON CONFLICT (player_id) DO UPDATE SET
         full_name=EXCLUDED.full_name, first_name=EXCLUDED.first_name, last_name=EXCLUDED.last_name,
         position=EXCLUDED.position, team=EXCLUDED.team, jersey_number=EXCLUDED.jersey_number,
         age=EXCLUDED.age, height_inches=EXCLUDED.height_inches, weight_lbs=EXCLUDED.weight_lbs,
         college=EXCLUDED.college, status=EXCLUDED.status, headshot_url=EXCLUDED.headshot_url,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((p) => [
        p.playerId, p.fullName, p.firstName, p.lastName, p.position, p.team, p.jerseyNumber,
        p.age, p.heightInches, p.weightLbs, p.college, p.status, p.headshotUrl,
        p.meta.source, p.meta.sourceUpdatedAt, p.meta.fetchedAt,
      ]),
    );
  }
  async getPlayers(filter: PlayerFilter): Promise<Player[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    if (filter.position) { params.push(filter.position); where.push(`position=$${params.length}`); }
    if (filter.team) { params.push(filter.team); where.push(`team=$${params.length}`); }
    if (filter.search) { params.push(`%${filter.search}%`); where.push(`full_name ILIKE $${params.length}`); }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
    const limitSql = filter.limit !== undefined ? `LIMIT ${Number(filter.limit)}` : "";
    const { rows } = await this.pool.query(
      `SELECT * FROM players ${whereSql} ORDER BY full_name ${limitSql}`,
      params,
    );
    return rows.map((r) => this.rowToPlayer(r));
  }
  async getPlayer(playerId: string): Promise<Player | undefined> {
    const { rows } = await this.pool.query("SELECT * FROM players WHERE player_id=$1", [playerId]);
    return rows[0] ? this.rowToPlayer(rows[0]) : undefined;
  }
  private rowToPlayer(r: Record<string, unknown>): Player {
    return {
      playerId: r.player_id as string,
      fullName: r.full_name as string,
      firstName: (r.first_name as string) ?? null,
      lastName: (r.last_name as string) ?? null,
      position: r.position as Position,
      team: (r.team as string) ?? null,
      jerseyNumber: numOrNull(r.jersey_number),
      age: numOrNull(r.age),
      heightInches: numOrNull(r.height_inches),
      weightLbs: numOrNull(r.weight_lbs),
      college: (r.college as string) ?? null,
      status: (r.status as string) ?? "Active",
      headshotUrl: (r.headshot_url as string) ?? null,
      meta: metaFrom(r),
    };
  }

  // ---- games ----
  async upsertGames(rows: Game[]): Promise<number> {
    return this.batch(
      `INSERT INTO games (game_id, season, week, season_type, home_team, away_team, kickoff,
         status, home_score, away_score, quarter, clock,
         source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15, now())
       ON CONFLICT (game_id) DO UPDATE SET
         season=EXCLUDED.season, week=EXCLUDED.week, season_type=EXCLUDED.season_type,
         home_team=EXCLUDED.home_team, away_team=EXCLUDED.away_team, kickoff=EXCLUDED.kickoff,
         status=EXCLUDED.status, home_score=EXCLUDED.home_score, away_score=EXCLUDED.away_score,
         quarter=EXCLUDED.quarter, clock=EXCLUDED.clock,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((g) => [
        g.gameId, g.season, g.week, g.seasonType, g.homeTeam, g.awayTeam, g.kickoff,
        g.status, g.homeScore, g.awayScore, g.quarter, g.clock,
        g.meta.source, g.meta.sourceUpdatedAt, g.meta.fetchedAt,
      ]),
    );
  }
  async getGames(filter: GameFilter): Promise<Game[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    if (filter.season !== undefined) { params.push(filter.season); where.push(`season=$${params.length}`); }
    if (filter.week !== undefined) { params.push(filter.week); where.push(`week=$${params.length}`); }
    if (filter.status) { params.push(filter.status); where.push(`status=$${params.length}`); }
    if (filter.team) { params.push(filter.team); where.push(`(home_team=$${params.length} OR away_team=$${params.length})`); }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
    const limitSql = filter.limit !== undefined ? `LIMIT ${Number(filter.limit)}` : "";
    const { rows } = await this.pool.query(
      `SELECT * FROM games ${whereSql} ORDER BY kickoff NULLS LAST ${limitSql}`,
      params,
    );
    return rows.map((r) => this.rowToGame(r));
  }
  async getGame(gameId: string): Promise<Game | undefined> {
    const { rows } = await this.pool.query("SELECT * FROM games WHERE game_id=$1", [gameId]);
    return rows[0] ? this.rowToGame(rows[0]) : undefined;
  }
  private rowToGame(r: Record<string, unknown>): Game {
    return {
      gameId: r.game_id as string,
      season: num(r.season),
      week: num(r.week),
      seasonType: (r.season_type as SeasonType) ?? "regular",
      homeTeam: r.home_team as string,
      awayTeam: r.away_team as string,
      kickoff: iso(r.kickoff as Date | null),
      status: (r.status as GameStatus) ?? "scheduled",
      homeScore: numOrNull(r.home_score),
      awayScore: numOrNull(r.away_score),
      quarter: numOrNull(r.quarter),
      clock: (r.clock as string) ?? null,
      meta: metaFrom(r),
    };
  }

  // ---- weekly stats ----
  async upsertWeeklyStats(rows: PlayerWeeklyStat[]): Promise<number> {
    return this.batch(
      `INSERT INTO player_weekly_stats (player_id, season, week, team, opponent,
         passing_yards, passing_tds, interceptions, completions, pass_attempts,
         carries, rushing_yards, rushing_tds,
         targets, receptions, receiving_yards, receiving_tds, air_yards, target_share,
         fumbles_lost, snaps, snap_share,
         fantasy_points_ppr, fantasy_points_half_ppr, fantasy_points_standard,
         source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28, now())
       ON CONFLICT (player_id, season, week) DO UPDATE SET
         team=EXCLUDED.team, opponent=EXCLUDED.opponent,
         passing_yards=EXCLUDED.passing_yards, passing_tds=EXCLUDED.passing_tds,
         interceptions=EXCLUDED.interceptions, completions=EXCLUDED.completions,
         pass_attempts=EXCLUDED.pass_attempts, carries=EXCLUDED.carries,
         rushing_yards=EXCLUDED.rushing_yards, rushing_tds=EXCLUDED.rushing_tds,
         targets=EXCLUDED.targets, receptions=EXCLUDED.receptions,
         receiving_yards=EXCLUDED.receiving_yards, receiving_tds=EXCLUDED.receiving_tds,
         air_yards=EXCLUDED.air_yards, target_share=EXCLUDED.target_share,
         fumbles_lost=EXCLUDED.fumbles_lost, snaps=EXCLUDED.snaps, snap_share=EXCLUDED.snap_share,
         fantasy_points_ppr=EXCLUDED.fantasy_points_ppr,
         fantasy_points_half_ppr=EXCLUDED.fantasy_points_half_ppr,
         fantasy_points_standard=EXCLUDED.fantasy_points_standard,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((s) => [
        s.playerId, s.season, s.week, s.team, s.opponent,
        s.passingYards, s.passingTds, s.interceptions, s.completions, s.passAttempts,
        s.carries, s.rushingYards, s.rushingTds,
        s.targets, s.receptions, s.receivingYards, s.receivingTds, s.airYards, s.targetShare,
        s.fumblesLost, s.snaps, s.snapShare,
        s.fantasyPointsPpr, s.fantasyPointsHalfPpr, s.fantasyPointsStandard,
        s.meta.source, s.meta.sourceUpdatedAt, s.meta.fetchedAt,
      ]),
    );
  }
  async getPlayerWeeklyStats(playerId: string, season?: number, week?: number): Promise<PlayerWeeklyStat[]> {
    const where = ["player_id=$1"];
    const params: unknown[] = [playerId];
    if (season !== undefined) { params.push(season); where.push(`season=$${params.length}`); }
    if (week !== undefined) { params.push(week); where.push(`week=$${params.length}`); }
    const { rows } = await this.pool.query(
      `SELECT * FROM player_weekly_stats WHERE ${where.join(" AND ")} ORDER BY season DESC, week DESC`,
      params,
    );
    return rows.map((r) => this.rowToWeekly(r));
  }
  private rowToWeekly(r: Record<string, unknown>): PlayerWeeklyStat {
    return {
      playerId: r.player_id as string,
      season: num(r.season),
      week: num(r.week),
      team: (r.team as string) ?? null,
      opponent: (r.opponent as string) ?? null,
      passingYards: num(r.passing_yards),
      passingTds: num(r.passing_tds),
      interceptions: num(r.interceptions),
      completions: num(r.completions),
      passAttempts: num(r.pass_attempts),
      carries: num(r.carries),
      rushingYards: num(r.rushing_yards),
      rushingTds: num(r.rushing_tds),
      targets: num(r.targets),
      receptions: num(r.receptions),
      receivingYards: num(r.receiving_yards),
      receivingTds: num(r.receiving_tds),
      airYards: num(r.air_yards),
      targetShare: num(r.target_share),
      fumblesLost: num(r.fumbles_lost),
      snaps: num(r.snaps),
      snapShare: num(r.snap_share),
      fantasyPointsPpr: num(r.fantasy_points_ppr),
      fantasyPointsHalfPpr: num(r.fantasy_points_half_ppr),
      fantasyPointsStandard: num(r.fantasy_points_standard),
      meta: metaFrom(r),
    };
  }

  // ---- projections ----
  async upsertProjections(rows: PlayerProjection[]): Promise<number> {
    return this.batch(
      `INSERT INTO player_projections (player_id, season, week,
         proj_passing_yards, proj_passing_tds, proj_rushing_yards, proj_rushing_tds,
         proj_receptions, proj_receiving_yards, proj_receiving_tds,
         proj_fantasy_points_ppr, proj_fantasy_points_half_ppr, proj_fantasy_points_standard,
         floor, ceiling, source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18, now())
       ON CONFLICT (player_id, season, week) DO UPDATE SET
         proj_passing_yards=EXCLUDED.proj_passing_yards, proj_passing_tds=EXCLUDED.proj_passing_tds,
         proj_rushing_yards=EXCLUDED.proj_rushing_yards, proj_rushing_tds=EXCLUDED.proj_rushing_tds,
         proj_receptions=EXCLUDED.proj_receptions, proj_receiving_yards=EXCLUDED.proj_receiving_yards,
         proj_receiving_tds=EXCLUDED.proj_receiving_tds,
         proj_fantasy_points_ppr=EXCLUDED.proj_fantasy_points_ppr,
         proj_fantasy_points_half_ppr=EXCLUDED.proj_fantasy_points_half_ppr,
         proj_fantasy_points_standard=EXCLUDED.proj_fantasy_points_standard,
         floor=EXCLUDED.floor, ceiling=EXCLUDED.ceiling,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((p) => [
        p.playerId, p.season, p.week,
        p.projPassingYards, p.projPassingTds, p.projRushingYards, p.projRushingTds,
        p.projReceptions, p.projReceivingYards, p.projReceivingTds,
        p.projFantasyPointsPpr, p.projFantasyPointsHalfPpr, p.projFantasyPointsStandard,
        p.floor, p.ceiling, p.meta.source, p.meta.sourceUpdatedAt, p.meta.fetchedAt,
      ]),
    );
  }
  async getPlayerProjections(playerId: string, season?: number, week?: number): Promise<PlayerProjection[]> {
    const where = ["player_id=$1"];
    const params: unknown[] = [playerId];
    if (season !== undefined) { params.push(season); where.push(`season=$${params.length}`); }
    if (week !== undefined) { params.push(week); where.push(`week=$${params.length}`); }
    const { rows } = await this.pool.query(
      `SELECT * FROM player_projections WHERE ${where.join(" AND ")} ORDER BY season DESC, week DESC`,
      params,
    );
    return rows.map((r) => this.rowToProjection(r));
  }
  private rowToProjection(r: Record<string, unknown>): PlayerProjection {
    return {
      playerId: r.player_id as string,
      season: num(r.season),
      week: num(r.week),
      projPassingYards: num(r.proj_passing_yards),
      projPassingTds: num(r.proj_passing_tds),
      projRushingYards: num(r.proj_rushing_yards),
      projRushingTds: num(r.proj_rushing_tds),
      projReceptions: num(r.proj_receptions),
      projReceivingYards: num(r.proj_receiving_yards),
      projReceivingTds: num(r.proj_receiving_tds),
      projFantasyPointsPpr: num(r.proj_fantasy_points_ppr),
      projFantasyPointsHalfPpr: num(r.proj_fantasy_points_half_ppr),
      projFantasyPointsStandard: num(r.proj_fantasy_points_standard),
      floor: num(r.floor),
      ceiling: num(r.ceiling),
      meta: metaFrom(r),
    };
  }

  // ---- injuries ----
  async upsertInjuries(rows: Injury[]): Promise<number> {
    return this.batch(
      `INSERT INTO injuries (player_id, season, week, status, body_part, practice_status,
         return_estimate, report_date, note, source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12, now())
       ON CONFLICT (player_id, season, week) DO UPDATE SET
         status=EXCLUDED.status, body_part=EXCLUDED.body_part, practice_status=EXCLUDED.practice_status,
         return_estimate=EXCLUDED.return_estimate, report_date=EXCLUDED.report_date, note=EXCLUDED.note,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((i) => [
        i.playerId, i.season, i.week, i.status, i.bodyPart, i.practiceStatus,
        i.returnEstimate, i.reportDate, i.note,
        i.meta.source, i.meta.sourceUpdatedAt, i.meta.fetchedAt,
      ]),
    );
  }
  async getPlayerInjury(playerId: string): Promise<Injury | undefined> {
    const { rows } = await this.pool.query(
      "SELECT * FROM injuries WHERE player_id=$1 ORDER BY season DESC, week DESC LIMIT 1",
      [playerId],
    );
    return rows[0] ? this.rowToInjury(rows[0]) : undefined;
  }
  async getInjuries(filter: InjuryFilter): Promise<Injury[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    if (filter.season !== undefined) { params.push(filter.season); where.push(`i.season=$${params.length}`); }
    if (filter.week !== undefined) { params.push(filter.week); where.push(`i.week=$${params.length}`); }
    if (filter.team) { params.push(filter.team); where.push(`p.team=$${params.length}`); }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
    const { rows } = await this.pool.query(
      `SELECT i.* FROM injuries i JOIN players p USING (player_id) ${whereSql}
       ORDER BY i.season DESC, i.week DESC`,
      params,
    );
    return rows.map((r) => this.rowToInjury(r));
  }
  private rowToInjury(r: Record<string, unknown>): Injury {
    return {
      playerId: r.player_id as string,
      season: num(r.season),
      week: num(r.week),
      status: (r.status as InjuryDesignation) ?? "Healthy",
      bodyPart: (r.body_part as string) ?? null,
      practiceStatus: (r.practice_status as string) ?? null,
      returnEstimate: (r.return_estimate as string) ?? null,
      reportDate: iso(r.report_date as Date | null),
      note: (r.note as string) ?? null,
      meta: metaFrom(r),
    };
  }

  // ---- leagues / rosters / matchups ----
  async upsertLeague(l: FantasyLeague): Promise<void> {
    await this.pool.query(
      `INSERT INTO fantasy_leagues (league_id, platform, name, season, scoring, team_count,
         superflex, dynasty, roster_slots, source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12, now())
       ON CONFLICT (league_id) DO UPDATE SET
         platform=EXCLUDED.platform, name=EXCLUDED.name, season=EXCLUDED.season,
         scoring=EXCLUDED.scoring, team_count=EXCLUDED.team_count, superflex=EXCLUDED.superflex,
         dynasty=EXCLUDED.dynasty, roster_slots=EXCLUDED.roster_slots,
         source=EXCLUDED.source, source_updated_at=EXCLUDED.source_updated_at,
         fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      [
        l.leagueId, l.platform, l.name, l.season, l.scoring, l.teamCount, l.superflex, l.dynasty,
        JSON.stringify(l.rosterSlots), l.meta.source, l.meta.sourceUpdatedAt, l.meta.fetchedAt,
      ],
    );
  }
  async getLeague(leagueId: string): Promise<FantasyLeague | undefined> {
    const { rows } = await this.pool.query("SELECT * FROM fantasy_leagues WHERE league_id=$1", [leagueId]);
    return rows[0] ? this.rowToLeague(rows[0]) : undefined;
  }
  private rowToLeague(r: Record<string, unknown>): FantasyLeague {
    return {
      leagueId: r.league_id as string,
      platform: (r.platform as string) ?? "sleeper",
      name: r.name as string,
      season: num(r.season),
      scoring: (r.scoring as ScoringFormat) ?? "ppr",
      teamCount: num(r.team_count),
      superflex: Boolean(r.superflex),
      dynasty: Boolean(r.dynasty),
      rosterSlots: (r.roster_slots as Record<string, number>) ?? {},
      meta: metaFrom(r),
    };
  }

  async upsertRosters(rows: FantasyRoster[]): Promise<number> {
    return this.batch(
      `INSERT INTO fantasy_rosters (league_id, roster_id, owner_id, team_name, owner_name,
         player_ids, starters, wins, losses, ties, points_for, points_against,
         source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15, now())
       ON CONFLICT (league_id, roster_id) DO UPDATE SET
         owner_id=EXCLUDED.owner_id, team_name=EXCLUDED.team_name, owner_name=EXCLUDED.owner_name,
         player_ids=EXCLUDED.player_ids, starters=EXCLUDED.starters, wins=EXCLUDED.wins,
         losses=EXCLUDED.losses, ties=EXCLUDED.ties, points_for=EXCLUDED.points_for,
         points_against=EXCLUDED.points_against, source=EXCLUDED.source,
         source_updated_at=EXCLUDED.source_updated_at, fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((r) => [
        r.leagueId, r.rosterId, r.ownerId, r.teamName, r.ownerName,
        JSON.stringify(r.playerIds), JSON.stringify(r.starters),
        r.wins, r.losses, r.ties, r.pointsFor, r.pointsAgainst,
        r.meta.source, r.meta.sourceUpdatedAt, r.meta.fetchedAt,
      ]),
    );
  }
  async getLeagueRosters(leagueId: string): Promise<FantasyRoster[]> {
    const { rows } = await this.pool.query(
      "SELECT * FROM fantasy_rosters WHERE league_id=$1 ORDER BY roster_id",
      [leagueId],
    );
    return rows.map((r) => this.rowToRoster(r));
  }
  async getRoster(leagueId: string, rosterId: string): Promise<FantasyRoster | undefined> {
    const { rows } = await this.pool.query(
      "SELECT * FROM fantasy_rosters WHERE league_id=$1 AND roster_id=$2",
      [leagueId, rosterId],
    );
    return rows[0] ? this.rowToRoster(rows[0]) : undefined;
  }
  private rowToRoster(r: Record<string, unknown>): FantasyRoster {
    return {
      leagueId: r.league_id as string,
      rosterId: r.roster_id as string,
      ownerId: (r.owner_id as string) ?? null,
      teamName: (r.team_name as string) ?? null,
      ownerName: (r.owner_name as string) ?? null,
      playerIds: (r.player_ids as string[]) ?? [],
      starters: (r.starters as string[]) ?? [],
      wins: num(r.wins),
      losses: num(r.losses),
      ties: num(r.ties),
      pointsFor: num(r.points_for),
      pointsAgainst: num(r.points_against),
      meta: metaFrom(r),
    };
  }

  async upsertMatchups(rows: FantasyMatchup[]): Promise<number> {
    return this.batch(
      `INSERT INTO fantasy_matchups (league_id, week, matchup_id, roster_id, opponent_roster_id,
         points, projected_points, is_winner, source, source_updated_at, fetched_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now())
       ON CONFLICT (league_id, week, roster_id) DO UPDATE SET
         matchup_id=EXCLUDED.matchup_id, opponent_roster_id=EXCLUDED.opponent_roster_id,
         points=EXCLUDED.points, projected_points=EXCLUDED.projected_points,
         is_winner=EXCLUDED.is_winner, source=EXCLUDED.source,
         source_updated_at=EXCLUDED.source_updated_at, fetched_at=EXCLUDED.fetched_at, updated_at=now()`,
      rows.map((m) => [
        m.leagueId, m.week, m.matchupId, m.rosterId, m.opponentRosterId,
        m.points, m.projectedPoints, m.isWinner,
        m.meta.source, m.meta.sourceUpdatedAt, m.meta.fetchedAt,
      ]),
    );
  }
  async getLeagueMatchups(leagueId: string, week?: number): Promise<FantasyMatchup[]> {
    const where = ["league_id=$1"];
    const params: unknown[] = [leagueId];
    if (week !== undefined) { params.push(week); where.push(`week=$${params.length}`); }
    const { rows } = await this.pool.query(
      `SELECT * FROM fantasy_matchups WHERE ${where.join(" AND ")} ORDER BY week, matchup_id`,
      params,
    );
    return rows.map((r) => this.rowToMatchup(r));
  }
  private rowToMatchup(r: Record<string, unknown>): FantasyMatchup {
    return {
      leagueId: r.league_id as string,
      week: num(r.week),
      matchupId: r.matchup_id as string,
      rosterId: r.roster_id as string,
      opponentRosterId: (r.opponent_roster_id as string) ?? null,
      points: num(r.points),
      projectedPoints: numOrNull(r.projected_points),
      isWinner: r.is_winner === null || r.is_winner === undefined ? null : Boolean(r.is_winner),
      meta: metaFrom(r),
    };
  }

  // ---- ai recommendations ----
  async insertRecommendation(rec: AiRecommendation): Promise<void> {
    await this.pool.query(
      `INSERT INTO ai_recommendations (id, league_id, kind, subject_player_ids, recommendation,
         reasoning, key_stats_used, confidence, source_timestamps, missing_data_warning, created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now())
       ON CONFLICT (id) DO NOTHING`,
      [
        rec.id, rec.leagueId, rec.kind, JSON.stringify(rec.subjectPlayerIds), rec.recommendation,
        rec.reasoning, JSON.stringify(rec.keyStatsUsed), rec.confidence,
        JSON.stringify(rec.sourceTimestamps), rec.missingDataWarning,
      ],
    );
  }
  async getRecommendations(filter: {
    leagueId?: string;
    kind?: RecommendationKind;
    limit?: number;
  }): Promise<AiRecommendation[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    if (filter.leagueId) { params.push(filter.leagueId); where.push(`league_id=$${params.length}`); }
    if (filter.kind) { params.push(filter.kind); where.push(`kind=$${params.length}`); }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
    const limitSql = filter.limit !== undefined ? `LIMIT ${Number(filter.limit)}` : "";
    const { rows } = await this.pool.query(
      `SELECT * FROM ai_recommendations ${whereSql} ORDER BY created_at DESC ${limitSql}`,
      params,
    );
    return rows.map((r) => this.rowToRec(r));
  }
  private rowToRec(r: Record<string, unknown>): AiRecommendation {
    return {
      id: r.id as string,
      leagueId: (r.league_id as string) ?? null,
      kind: r.kind as RecommendationKind,
      subjectPlayerIds: (r.subject_player_ids as string[]) ?? [],
      recommendation: r.recommendation as string,
      reasoning: r.reasoning as string,
      keyStatsUsed: (r.key_stats_used as KeyStat[]) ?? [],
      confidence: num(r.confidence),
      sourceTimestamps: (r.source_timestamps as Record<string, string>) ?? {},
      missingDataWarning: (r.missing_data_warning as string) ?? null,
      createdAt: iso(r.created_at as Date | null) ?? new Date().toISOString(),
    };
  }
}
