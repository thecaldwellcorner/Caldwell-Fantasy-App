-- Caldwell IQ — Sleeper league connection (migration 003)
--
-- Run once in the Supabase SQL editor. Stores a connected Sleeper account, the
-- user's leagues, and the imported rosters. The iOS app writes these with the
-- publishable (anon) key under the permissive RLS policies below (there is no
-- per-user auth yet). NEVER put the service-role key in the app.
--
-- NOTE: an earlier data-layer migration may have created differently-shaped
-- `fantasy_leagues` / `fantasy_rosters` tables (keyed by text ids). Those were
-- never populated. If they exist, drop them first (uncomment) before running:
--   drop table if exists fantasy_rosters cascade;
--   drop table if exists fantasy_leagues cascade;

create extension if not exists pgcrypto;

-- 1. connected_fantasy_accounts ---------------------------------------------
create table if not exists connected_fantasy_accounts (
    id                uuid primary key default gen_random_uuid(),
    app_user_id       uuid not null,
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

-- 2. fantasy_leagues ---------------------------------------------------------
create table if not exists fantasy_leagues (
    id                 uuid primary key default gen_random_uuid(),
    app_user_id        uuid not null,
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

-- 3. fantasy_rosters ---------------------------------------------------------
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

-- RLS — permissive (no per-user auth yet). Reads/writes use the publishable key.
alter table connected_fantasy_accounts enable row level security;
alter table fantasy_leagues enable row level security;
alter table fantasy_rosters enable row level security;

do $$
begin
    if not exists (select 1 from pg_policies where tablename = 'connected_fantasy_accounts' and policyname = 'anon all cfa') then
        create policy "anon all cfa" on connected_fantasy_accounts for all to anon using (true) with check (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'fantasy_leagues' and policyname = 'anon all fl') then
        create policy "anon all fl" on fantasy_leagues for all to anon using (true) with check (true);
    end if;
    if not exists (select 1 from pg_policies where tablename = 'fantasy_rosters' and policyname = 'anon all fr') then
        create policy "anon all fr" on fantasy_rosters for all to anon using (true) with check (true);
    end if;
end $$;
