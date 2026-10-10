-- Крок 5: gold.dim_repo. Специфікація: ../../SPEC.md → «Крок 5».
-- Джерело: {{ ref('events') }}. Грануляція: один рядок на репозиторій.
-- Колонки: repo_id (md5(repo_name)), repo_name, repo_owner, first_seen_at, last_seen_at,
--          event_count, is_forked (є хоч одна подія ForkEvent по цьому репо).

-- TODO: замініть заглушку на запит згідно зі SPEC.md
with 
    prep as (
        select 
            md5(repo_name)                          as repo_id,
            repo_name,
            repo_owner,
            min(created_at)                         as first_seen_at,
            max(created_at)                         as last_seen_at,
            count(*)                                as event_count,
            sum(if(event_type = 'ForkEvent', 1, 0)) as fork_event_count
        from {{ ref('events') }} 
        group by 
            repo_name, repo_owner
    )

    select
        cast(repo_id                    as string   )   as repo_id,
        cast(repo_name                  as string   )   as repo_name,
        cast(repo_owner                 as string   )   as repo_owner,
        cast(first_seen_at              as timestamp)   as first_seen_at,
        cast(last_seen_at               as timestamp)   as last_seen_at,
        cast(event_count                as bigint   )   as event_count,
        cast((fork_event_count >= 1)    as boolean  )   as is_forked
    from prep
