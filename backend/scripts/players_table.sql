create table if not exists players (
  sleeper_id text primary key,
  full_name text,
  first_name text,
  last_name text,
  team text,
  position text,
  age integer,
  height text,
  weight text,
  active boolean,
  fantasy_positions text[],
  updated_at timestamptz default now()
);
