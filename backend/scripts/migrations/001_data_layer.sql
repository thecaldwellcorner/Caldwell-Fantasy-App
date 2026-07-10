-- Caldwell IQ data layer — migration 001
-- Adds games, weekly stats, advanced stats, projections, images, and sync-run
-- tracking. Run once in the Supabase SQL editor (or via the CLI).
--
-- These tables reference players(id). The existing `players` table is keyed by
-- `sleeper_id`, so we first add a stable uuid `id` and backfill it.

create extension if not exists pgcrypto;

-- Ensure players has a uuid id for foreign keys (keeps sleeper_id as-is).
alter table players add column if not exists id uuid default gen_random_uuid();
update players set id = gen_random_uuid() where id is null;
alter table players alter column id set not null;
create unique index if not exists players_id_key on players (id);

-- 1. games -------------------------------------------------------------------
create table if not exists games (
    id                uuid primary key default gen_random_uuid(),
    provider_game_id  text unique not null,
    season            integer,
    week              integer,
    season_type       text,
    home_team         text,
    away_team         text,
    home_score        integer,
    away_score        integer,
    kickoff_at        timestamptz,
    status            text,
    venue             text,
    source            text,
    updated_at        timestamptz default now()
);
create index if not exists idx_games_season_week on games (season, week);

-- 2. player_weekly_stats -----------------------------------------------------
create table if not exists player_weekly_stats (
    id                     uuid primary key default gen_random_uuid(),
    player_id              uuid references players(id) on delete cascade,
    provider_player_id     text,
    season                 integer,
    week                   integer,
    team                   text,
    opponent               text,
    passing_yards          numeric,
    passing_touchdowns     numeric,
    interceptions          numeric,
    rushing_attempts       numeric,
    rushing_yards          numeric,
    rushing_touchdowns     numeric,
    targets                numeric,
    receptions             numeric,
    receiving_yards        numeric,
    receiving_touchdowns   numeric,
    fumbles_lost           numeric,
    fantasy_points_ppr     numeric,
    fantasy_points_half_ppr numeric,
    fantasy_points_standard numeric,
    source                 text,
    updated_at             timestamptz default now(),
    unique (player_id, season, week, source)
);
create index if not exists idx_pws_player on player_weekly_stats (player_id);
create index if not exists idx_pws_season_week on player_weekly_stats (season, week);

-- 3. player_advanced_stats ---------------------------------------------------
create table if not exists player_advanced_stats (
    id                            uuid primary key default gen_random_uuid(),
    player_id                     uuid references players(id) on delete cascade,
    season                        integer,
    week                          integer,
    epa_per_play                  numeric,
    success_rate                  numeric,
    target_share                  numeric,
    air_yards_share               numeric,
    route_participation           numeric,
    yards_per_route_run           numeric,
    expected_fantasy_points       numeric,
    fantasy_points_over_expected  numeric,
    source                        text,
    updated_at                    timestamptz default now(),
    unique (player_id, season, week, source)
);
create index if not exists idx_pas_player on player_advanced_stats (player_id);

-- 4. player_projections ------------------------------------------------------
create table if not exists player_projections (
    id                        uuid primary key default gen_random_uuid(),
    player_id                 uuid references players(id) on delete cascade,
    season                    integer,
    week                      integer,
    projected_points_ppr      numeric,
    projected_points_half_ppr numeric,
    projected_points_standard numeric,
    floor                     numeric,
    ceiling                   numeric,
    confidence                numeric,
    projection_source         text,
    model_version             text,
    updated_at                timestamptz default now(),
    unique (player_id, season, week, projection_source)
);
create index if not exists idx_proj_player on player_projections (player_id);

-- 5. player_images -----------------------------------------------------------
create table if not exists player_images (
    id                 uuid primary key default gen_random_uuid(),
    player_id          uuid references players(id) on delete cascade,
    image_url          text,
    image_type         text,
    provider           text,
    license_reference  text,
    updated_at         timestamptz default now(),
    unique (player_id, image_type)
);

-- 6. data_sync_runs ----------------------------------------------------------
create table if not exists data_sync_runs (
    id             uuid primary key default gen_random_uuid(),
    sync_type      text,
    source         text,
    started_at     timestamptz,
    completed_at   timestamptz,
    status         text,
    rows_processed integer,
    error_message  text
);

-- Read policies for the anon role (the iOS app reads with the publishable key).
-- Writes happen only from server-side scripts using the service-role key.
alter table games enable row level security;
alter table player_weekly_stats enable row level security;
alter table player_advanced_stats enable row level security;
alter table player_projections enable row level security;
alter table player_images enable row level security;

do $$
begin
    if not exists (select 1 from pg_policies where tablename = 'games' and policyname = 'public read games') then
        create policy "public read games" on games for select to anon using (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'player_weekly_stats' and policyname = 'public read pws') then
        create policy "public read pws" on player_weekly_stats for select to anon using (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'player_advanced_stats' and policyname = 'public read pas') then
        create policy "public read pas" on player_advanced_stats for select to anon using (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'player_projections' and policyname = 'public read proj') then
        create policy "public read proj" on player_projections for select to anon using (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'player_images' and policyname = 'public read images') then
        create policy "public read images" on player_images for select to anon using (true);
    end if;
end $$;
