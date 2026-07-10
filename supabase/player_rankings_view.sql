-- Caldwell IQ — player_rankings view
--
-- Ranks fantasy-relevant, ACTIVE QB/RB/WR/TE by a data-driven relevance score
-- computed from the most recent season that actually has weekly stats. Run this
-- in the Supabase SQL editor after migrating + importing weekly stats.
--
-- The iOS app reads this view directly via PostgREST:
--   /rest/v1/player_rankings?order=relevance_score.desc&limit=300
--   ...&position=in.(RB,WR,TE)      (FLEX)   ...&full_name=ilike.*name*   (search)
--   ...&games_played=gt.0           (default pool = players with production)
--
-- Relevance weighting (each component normalized 0..1 across the pool):
--   50% latest-season total PPR
--   20% latest-season PPR per game
--   10% games played
--   10% recent usage (position-aware volume from available columns)
--   10% flat eligibility baseline
-- Passing attempts aren't in player_weekly_stats, so QB usage uses rushing
-- attempts + receiving volume; elite QBs still surface via points (70% weight).

create or replace view player_rankings as
with latest as (
    select max(season) as season from player_weekly_stats
),
agg as (
    select
        s.player_id,
        sum(coalesce(s.fantasy_points_ppr, 0))                                   as total_ppr,
        count(*)                                                                 as games_played,
        avg(coalesce(s.fantasy_points_ppr, 0))                                   as ppg,
        sum(coalesce(s.rushing_attempts, 0)
            + coalesce(s.targets, 0)
            + coalesce(s.receptions, 0))                                         as usage_raw
    from player_weekly_stats s
    join latest l on s.season = l.season
    group by s.player_id
),
eligible as (
    select
        p.id                                     as player_id,
        p.sleeper_id                             as sleeper_id,
        p.full_name                              as full_name,
        p.position                               as position,
        p.team                                   as team,
        p.age                                    as age,
        p.height                                 as height,
        p.weight                                 as weight,
        (select season from latest)              as latest_season,
        coalesce(a.total_ppr, 0)                 as total_fantasy_points_ppr,
        coalesce(a.games_played, 0)              as games_played,
        coalesce(a.ppg, 0)                       as fantasy_points_per_game,
        coalesce(a.usage_raw, 0)                 as recent_usage
    from players p
    left join agg a on a.player_id = p.id
    where p.active = true
      and p.position in ('QB', 'RB', 'WR', 'TE')
      and p.team is not null
      and p.team <> 'FA'
)
select
    e.*,
    round((
        0.5 * coalesce(e.total_fantasy_points_ppr / nullif(max(e.total_fantasy_points_ppr) over (), 0), 0)
      + 0.2 * coalesce(e.fantasy_points_per_game   / nullif(max(e.fantasy_points_per_game)   over (), 0), 0)
      + 0.1 * coalesce(e.games_played::numeric      / nullif(max(e.games_played)      over (), 0), 0)
      + 0.1 * coalesce(e.recent_usage               / nullif(max(e.recent_usage)      over (), 0), 0)
      + 0.1
    ) * 100, 2) as relevance_score
from eligible e;

-- The iOS app reads with the publishable (anon) key.
grant select on player_rankings to anon, authenticated;
