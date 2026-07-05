-- Supabase table for the Sleeper player sync (syncSleeperPlayers.js).
-- Run this once in the Supabase SQL editor (or via the CLI) before syncing.
-- `sleeper_id` is the primary key and the upsert conflict target.

create table if not exists public.players (
    sleeper_id        text primary key,
    full_name         text,
    first_name        text,
    last_name         text,
    team              text,
    position          text,
    age               integer,
    height            text,
    weight            text,
    active            boolean default false,
    fantasy_positions text[] default '{}',
    updated_at        timestamptz default now()
);

create index if not exists idx_players_position on public.players (position);
create index if not exists idx_players_team on public.players (team);

-- Row Level Security: keep the table private. The sync script uses the service
-- role key (which bypasses RLS); the iOS app should read players only through
-- your backend, never directly with the service role key.
alter table public.players enable row level security;
