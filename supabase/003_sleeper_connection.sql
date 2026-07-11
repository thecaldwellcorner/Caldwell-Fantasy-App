-- Caldwell IQ — Sleeper league connection (migration 003, AUTH-SCOPED)
--
-- Requires Supabase Auth. The iOS app keeps the PUBLISHABLE key but must have a
-- signed-in Supabase user before syncing/reading leagues; `app_user_id` must be
-- that user's id (auth.uid()). RLS then limits every row to its owner.
--
-- Safe to re-run: tables use CREATE TABLE IF NOT EXISTS; policies are dropped
-- and recreated. No tables are dropped.
--
-- NOTE: `fantasy_league_users` and `fantasy_roster_players` are intentionally
-- NOT created — the current integration stores each roster's players/starters/
-- reserve/taxi as JSONB on `fantasy_rosters` and matches those Sleeper IDs to
-- `players.sleeper_id` at read time, so no separate join tables are needed yet.
--
-- If a prior data-layer migration created differently-shaped, UNPOPULATED
-- `fantasy_leagues` / `fantasy_rosters` tables, reconcile them manually before
-- running (this migration never drops tables).

create extension if not exists pgcrypto;

-- 1. connected_fantasy_accounts --------------------------------------------
create table if not exists connected_fantasy_accounts (
    id                uuid primary key default gen_random_uuid(),
    app_user_id       uuid not null references auth.users(id) on delete cascade,
    platform          text not null,
    platform_user_id  text not null,
    platform_username text,
    display_name      text,
    avatar_url        text,
    connected_at      timestamptz not null default now(),
    updated_at        timestamptz not null default now(),
    unique (app_user_id, platform)
);
create index if not exists idx_cfa_app_user on connected_fantasy_accounts (app_user_id);

-- 2. fantasy_leagues --------------------------------------------------------
create table if not exists fantasy_leagues (
    id                 uuid primary key default gen_random_uuid(),
    app_user_id        uuid not null references auth.users(id) on delete cascade,
    platform           text not null,
    platform_league_id text not null,
    name               text,
    season             integer,
    total_rosters      integer,
    scoring_settings   jsonb,
    roster_positions   jsonb,
    status             text,
    selected           boolean not null default false,
    synced_at          timestamptz not null default now(),
    unique (app_user_id, platform, platform_league_id)
);
create index if not exists idx_fl_app_user on fantasy_leagues (app_user_id);

-- 3. fantasy_rosters --------------------------------------------------------
create table if not exists fantasy_rosters (
    id                 uuid primary key default gen_random_uuid(),
    fantasy_league_id  uuid not null references fantasy_leagues(id) on delete cascade,
    platform_roster_id integer,
    platform_owner_id  text,
    is_user_roster     boolean not null default false,
    players            jsonb,
    starters           jsonb,
    reserve            jsonb,
    taxi               jsonb,
    synced_at          timestamptz not null default now(),
    unique (fantasy_league_id, platform_roster_id)
);
create index if not exists idx_fr_league on fantasy_rosters (fantasy_league_id);

-- Row Level Security --------------------------------------------------------
alter table connected_fantasy_accounts enable row level security;
alter table fantasy_leagues enable row level security;
alter table fantasy_rosters enable row level security;

-- Remove any prior permissive/owner policies (rerun-safe).
drop policy if exists "anon all cfa" on connected_fantasy_accounts;
drop policy if exists "anon all fl" on fantasy_leagues;
drop policy if exists "anon all fr" on fantasy_rosters;
drop policy if exists "own connected accounts" on connected_fantasy_accounts;
drop policy if exists "own leagues" on fantasy_leagues;
drop policy if exists "own rosters" on fantasy_rosters;

-- Owner-scoped access for signed-in users only.
create policy "own connected accounts" on connected_fantasy_accounts
    for all to authenticated
    using (app_user_id = auth.uid())
    with check (app_user_id = auth.uid());

create policy "own leagues" on fantasy_leagues
    for all to authenticated
    using (app_user_id = auth.uid())
    with check (app_user_id = auth.uid());

-- A roster is accessible only when its parent league belongs to the caller.
create policy "own rosters" on fantasy_rosters
    for all to authenticated
    using (
        exists (
            select 1 from fantasy_leagues fl
            where fl.id = fantasy_rosters.fantasy_league_id
              and fl.app_user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1 from fantasy_leagues fl
            where fl.id = fantasy_rosters.fantasy_league_id
              and fl.app_user_id = auth.uid()
        )
    );
