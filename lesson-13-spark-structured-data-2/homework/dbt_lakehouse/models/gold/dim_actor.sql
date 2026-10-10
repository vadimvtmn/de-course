-- Крок 6: gold.dim_actor. Специфікація: ../../SPEC.md → «Крок 6».
-- Джерело: {{ ref('events') }}, actor_login is not null. Грануляція: один рядок на актора.
-- Колонки: actor_id (md5(actor_login)), actor_login, is_bot (закінчується на [bot]),
--          first_seen_at, last_seen_at, event_count, distinct_repos.

-- TODO: замініть заглушку на запит згідно зі SPEC.md

with 
    prep as (
        select 
            md5(actor_login)            as actor_id,
            actor_login,
            (actor_login like '%[bot]') as is_bot,
            min(created_at)             as first_seen_at,
            max(created_at)             as last_seen_at,
            count(*)                    as event_count,
            count(distinct repo_name)   as distinct_repos
        from {{ ref('events') }} 
        where actor_login is not null
        group by actor_login
    )

    select
        cast(actor_id       as string   ) as actor_id,
        cast(actor_login    as string   ) as actor_login,
        cast(is_bot         as boolean  ) as is_bot,
        cast(first_seen_at  as timestamp) as first_seen_at,
        cast(last_seen_at   as timestamp) as last_seen_at,
        cast(event_count    as bigint   ) as event_count,
        cast(distinct_repos as bigint   ) as distinct_repos
    from prep
