-- Caldwell Corner Fantasy Football — PostgreSQL schema
-- Stores normalized player metrics ingested from trusted sources
-- (Sleeper public API + nflverse / nflfastR-style datasets).

CREATE TABLE IF NOT EXISTS players (
    player_id   TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    position    TEXT NOT NULL,
    team        TEXT NOT NULL,
    age         INTEGER,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS player_metrics (
    player_id          TEXT NOT NULL REFERENCES players(player_id) ON DELETE CASCADE,
    season             INTEGER NOT NULL,
    week               INTEGER NOT NULL,            -- 0 = season-to-date

    -- usage / opportunity
    target_share       DOUBLE PRECISION NOT NULL DEFAULT 0,
    air_yards          DOUBLE PRECISION NOT NULL DEFAULT 0,
    routes_run         DOUBLE PRECISION NOT NULL DEFAULT 0,
    snap_share         DOUBLE PRECISION NOT NULL DEFAULT 0,
    red_zone_usage     DOUBLE PRECISION NOT NULL DEFAULT 0,

    -- context
    epa_team_context   DOUBLE PRECISION NOT NULL DEFAULT 50,
    matchup_difficulty DOUBLE PRECISION NOT NULL DEFAULT 50,
    injury_status      TEXT NOT NULL DEFAULT 'Healthy',

    -- derived outputs
    projected_points   DOUBLE PRECISION NOT NULL DEFAULT 0,
    regression_score   DOUBLE PRECISION NOT NULL DEFAULT 0,
    breakout_score     DOUBLE PRECISION NOT NULL DEFAULT 0,
    confidence_score   DOUBLE PRECISION NOT NULL DEFAULT 0,

    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (player_id, season, week)
);

CREATE INDEX IF NOT EXISTS idx_player_metrics_season_week
    ON player_metrics (season, week);

CREATE INDEX IF NOT EXISTS idx_players_position
    ON players (position);

-- Tracks ingestion runs for observability / debugging.
CREATE TABLE IF NOT EXISTS ingestion_runs (
    id          BIGSERIAL PRIMARY KEY,
    source      TEXT NOT NULL,
    season      INTEGER NOT NULL,
    week        INTEGER NOT NULL,
    rows        INTEGER NOT NULL DEFAULT 0,
    status      TEXT NOT NULL,
    detail      TEXT,
    started_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ
);
