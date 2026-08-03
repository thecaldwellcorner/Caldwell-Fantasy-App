-- Caldwell IQ — Supabase / PostgreSQL schema for the fantasy data layer.
--
-- Design rules (mirrors the data-layer requirements):
--   * The iOS app NEVER talks to third-party APIs directly. It only reads these
--     tables through our backend. Provider API keys live in the backend env only.
--   * Every row is normalized and carries provenance so any stat "knows where it
--     came from": `source` (provider label), `source_updated_at` (the provider's
--     as-of time) and `fetched_at` (when we ingested it). `updated_at` is the last
--     write time in our store and powers the app's "last updated" UI.
--   * Data is pulled through pluggable provider adapters (mock today; SportsDataIO
--     / MySportsFeeds / Sportradar later) and Sleeper for league data.
--
-- Safe to run repeatedly (CREATE TABLE IF NOT EXISTS / idempotent).

-- ---------------------------------------------------------------------------
-- Reference: players & teams
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teams (
    team_id           TEXT PRIMARY KEY,               -- canonical abbreviation, e.g. 'CIN'
    name              TEXT NOT NULL,
    abbreviation      TEXT NOT NULL,
    conference        TEXT,
    division          TEXT,
    bye_week          INTEGER,
    logo_url          TEXT,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS players (
    player_id         TEXT PRIMARY KEY,               -- stable id (Sleeper/provider id)
    full_name         TEXT NOT NULL,
    first_name        TEXT,
    last_name         TEXT,
    position          TEXT NOT NULL,                  -- QB/RB/WR/TE/K/DEF
    team              TEXT REFERENCES teams(team_id) ON DELETE SET NULL,
    jersey_number     INTEGER,
    age               INTEGER,
    height_inches     INTEGER,
    weight_lbs        INTEGER,
    college           TEXT,
    status            TEXT NOT NULL DEFAULT 'Active', -- Active/Inactive
    headshot_url      TEXT,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_players_position ON players (position);
CREATE INDEX IF NOT EXISTS idx_players_team ON players (team);

-- ---------------------------------------------------------------------------
-- Games / schedule / live scores
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS games (
    game_id           TEXT PRIMARY KEY,
    season            INTEGER NOT NULL,
    week              INTEGER NOT NULL,
    season_type       TEXT NOT NULL DEFAULT 'regular', -- pre/regular/post
    home_team         TEXT NOT NULL,
    away_team         TEXT NOT NULL,
    kickoff           TIMESTAMPTZ,
    status            TEXT NOT NULL DEFAULT 'scheduled', -- scheduled/in_progress/final/postponed
    home_score        INTEGER,
    away_score        INTEGER,
    quarter           INTEGER,
    clock             TEXT,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_games_season_week ON games (season, week);
CREATE INDEX IF NOT EXISTS idx_games_status ON games (status);

-- ---------------------------------------------------------------------------
-- Actual weekly stats (box score). week = 0 means season-to-date.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_weekly_stats (
    player_id         TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    season            INTEGER NOT NULL,
    week              INTEGER NOT NULL,
    team              TEXT,
    opponent          TEXT,

    passing_yards     DOUBLE PRECISION NOT NULL DEFAULT 0,
    passing_tds       DOUBLE PRECISION NOT NULL DEFAULT 0,
    interceptions     DOUBLE PRECISION NOT NULL DEFAULT 0,
    completions       DOUBLE PRECISION NOT NULL DEFAULT 0,
    pass_attempts     DOUBLE PRECISION NOT NULL DEFAULT 0,

    carries           DOUBLE PRECISION NOT NULL DEFAULT 0,
    rushing_yards     DOUBLE PRECISION NOT NULL DEFAULT 0,
    rushing_tds       DOUBLE PRECISION NOT NULL DEFAULT 0,

    targets           DOUBLE PRECISION NOT NULL DEFAULT 0,
    receptions        DOUBLE PRECISION NOT NULL DEFAULT 0,
    receiving_yards   DOUBLE PRECISION NOT NULL DEFAULT 0,
    receiving_tds     DOUBLE PRECISION NOT NULL DEFAULT 0,
    air_yards         DOUBLE PRECISION NOT NULL DEFAULT 0,
    target_share      DOUBLE PRECISION NOT NULL DEFAULT 0, -- 0..1

    fumbles_lost      DOUBLE PRECISION NOT NULL DEFAULT 0,
    snaps             DOUBLE PRECISION NOT NULL DEFAULT 0,
    snap_share        DOUBLE PRECISION NOT NULL DEFAULT 0, -- 0..1

    fantasy_points_ppr      DOUBLE PRECISION NOT NULL DEFAULT 0,
    fantasy_points_half_ppr DOUBLE PRECISION NOT NULL DEFAULT 0,
    fantasy_points_standard DOUBLE PRECISION NOT NULL DEFAULT 0,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (player_id, season, week)
);
CREATE INDEX IF NOT EXISTS idx_weekly_season_week ON player_weekly_stats (season, week);

-- ---------------------------------------------------------------------------
-- Forward-looking projections. week = 0 means rest-of-season.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS player_projections (
    player_id         TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    season            INTEGER NOT NULL,
    week              INTEGER NOT NULL,

    proj_passing_yards    DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_passing_tds      DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_rushing_yards    DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_rushing_tds      DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_receptions       DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_receiving_yards  DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_receiving_tds    DOUBLE PRECISION NOT NULL DEFAULT 0,

    proj_fantasy_points_ppr      DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_fantasy_points_half_ppr DOUBLE PRECISION NOT NULL DEFAULT 0,
    proj_fantasy_points_standard DOUBLE PRECISION NOT NULL DEFAULT 0,
    floor             DOUBLE PRECISION NOT NULL DEFAULT 0,
    ceiling           DOUBLE PRECISION NOT NULL DEFAULT 0,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (player_id, season, week)
);
CREATE INDEX IF NOT EXISTS idx_projections_season_week ON player_projections (season, week);

-- ---------------------------------------------------------------------------
-- Injuries (weekly injury report; latest row per player/season/week)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS injuries (
    player_id         TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    season            INTEGER NOT NULL,
    week              INTEGER NOT NULL,
    status            TEXT NOT NULL DEFAULT 'Healthy', -- Healthy/Questionable/Doubtful/Out/IR/PUP/SUS
    body_part         TEXT,
    practice_status   TEXT,
    return_estimate   TEXT,
    report_date       TIMESTAMPTZ,
    note              TEXT,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (player_id, season, week)
);
CREATE INDEX IF NOT EXISTS idx_injuries_season_week ON injuries (season, week);

-- ---------------------------------------------------------------------------
-- Fantasy league data (from Sleeper or a mock league provider)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fantasy_leagues (
    league_id         TEXT PRIMARY KEY,
    platform          TEXT NOT NULL DEFAULT 'sleeper',
    name              TEXT NOT NULL,
    season            INTEGER NOT NULL,
    scoring           TEXT NOT NULL DEFAULT 'ppr',   -- ppr/half_ppr/standard
    team_count        INTEGER NOT NULL DEFAULT 12,
    superflex         BOOLEAN NOT NULL DEFAULT FALSE,
    dynasty           BOOLEAN NOT NULL DEFAULT FALSE,
    roster_slots      JSONB NOT NULL DEFAULT '{}'::jsonb,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS fantasy_rosters (
    league_id         TEXT NOT NULL REFERENCES fantasy_leagues(league_id) ON DELETE CASCADE,
    roster_id         TEXT NOT NULL,
    owner_id          TEXT,
    team_name         TEXT,
    owner_name        TEXT,
    player_ids        JSONB NOT NULL DEFAULT '[]'::jsonb, -- array of player_id
    starters          JSONB NOT NULL DEFAULT '[]'::jsonb, -- array of player_id
    wins              INTEGER NOT NULL DEFAULT 0,
    losses            INTEGER NOT NULL DEFAULT 0,
    ties              INTEGER NOT NULL DEFAULT 0,
    points_for        DOUBLE PRECISION NOT NULL DEFAULT 0,
    points_against    DOUBLE PRECISION NOT NULL DEFAULT 0,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (league_id, roster_id)
);

CREATE TABLE IF NOT EXISTS fantasy_matchups (
    league_id         TEXT NOT NULL REFERENCES fantasy_leagues(league_id) ON DELETE CASCADE,
    week              INTEGER NOT NULL,
    matchup_id        TEXT NOT NULL,
    roster_id         TEXT NOT NULL,
    opponent_roster_id TEXT,
    points            DOUBLE PRECISION NOT NULL DEFAULT 0,
    projected_points  DOUBLE PRECISION,
    is_winner         BOOLEAN,

    source            TEXT NOT NULL DEFAULT 'mock',
    source_updated_at TIMESTAMPTZ,
    fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (league_id, week, roster_id)
);
CREATE INDEX IF NOT EXISTS idx_matchups_league_week ON fantasy_matchups (league_id, week);

-- ---------------------------------------------------------------------------
-- Persisted AI recommendations (grounded in stored data only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_recommendations (
    id                TEXT PRIMARY KEY,
    league_id         TEXT,
    kind              TEXT NOT NULL,                  -- start_sit/trade/waiver
    subject_player_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    recommendation    TEXT NOT NULL,
    reasoning         TEXT NOT NULL,
    key_stats_used    JSONB NOT NULL DEFAULT '[]'::jsonb,
    confidence        DOUBLE PRECISION NOT NULL DEFAULT 0,
    source_timestamps JSONB NOT NULL DEFAULT '{}'::jsonb,
    missing_data_warning TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_recs_league_kind ON ai_recommendations (league_id, kind);
