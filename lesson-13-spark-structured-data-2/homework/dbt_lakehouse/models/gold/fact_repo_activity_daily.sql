-- Крок 10: gold.fact_repo_activity_daily. Специфікація: ../../SPEC.md → «Крок 10».
-- Грануляція: (repo_id, date_id). Багатоджерельний rollup з {{ ref('commits') }},
-- {{ ref('pull_requests') }}, {{ ref('issues') }} та {{ ref('events') }} (WatchEvent/ForkEvent).
-- Патерн: денний агрегат на джерело (метрика + нулі для решти) → union all → group by.
-- Відсутні метрики → 0, не NULL. Порядок і типи колонок у всіх CTE мають збігатися.
-- Колонки: activity_id (md5(concat_ws('|', repo_id, date_id))), repo_id, date_id, commits,
--          distinct_committers, prs_opened, prs_merged, issues_opened, issues_closed, stars, forks.

-- TODO: замініть заглушку на запит згідно зі SPEC.md
with 
    comm_agg as (
        select 
            md5(repo_name) as repo_id,
            date_format(pushed_at, 'yyyyMMdd') as date_id,
            count(*) as commits,
            count(distinct author_email) as distinct_committers
        from {{ ref('commits') }}
        group by repo_id, date_id
    ),

    pr_agg as (
        select 
            md5(repo_name) as repo_id,
            date_format(opened_at, 'yyyyMMdd') as open_date_id,
            date_format(merged_at, 'yyyyMMdd') as merge_date_id,
            count(*) as prs
        from {{ ref('pull_requests') }}
        group by repo_id, open_date_id, merge_date_id
    ),

    iss_agg as (
        select 
            md5(repo_name) as repo_id,
            date_format(opened_at, 'yyyyMMdd') as open_date_id,
            date_format(closed_at, 'yyyyMMdd') as close_date_id,
            count(*) as iss
        from {{ ref('issues') }}
        group by repo_id, open_date_id, closed_at
    ),

    ev_agg as (
        select 
            md5(repo_name) as repo_id, 
            date_format(created_at, 'yyyyMMdd') as date_id,
            sum(if(event_type = 'WatchEvent', 1, 0)) as stars,
            sum(if(event_type = 'ForkEvent', 1, 0)) as forks
        from {{ ref('events') }}
        where event_type in ('WatchEvent', 'ForkEvent')
        group by repo_id, date_id
    ),

    prep as (
        select 
            md5(concat_ws('|', repo_id, date_id)) as activity_id,
            repo_id,
            date_id,
            ifnull(c.commits, 0) as commits,
            ifnull(c.distinct_committers, 0) as distinct_committers,
            ifnull(po.prs, 0) as prs_opened,
            ifnull(pm.prs, 0) as prs_merged,
            ifnull(io.iss, 0) as issues_opened,
            ifnull(ic.iss, 0) as issues_closed,
            ifnull(e.stars, 0) as stars,
            ifnull(e.forks, 0) as forks
        from comm_agg as c 
        full join ev_agg as e using(repo_id, date_id)

        full join (
            select 
                repo_id, 
                open_date_id as date_id, 
                sum(prs) as prs
            from pr_agg 
            group by repo_id, date_id
        ) as po
            using(repo_id, date_id)

        full join (
            select 
                repo_id, 
                merge_date_id as date_id, 
                sum(prs) as prs
            from pr_agg 
            group by repo_id, date_id
        ) as pm
            using(repo_id, date_id)

        full join (
            select 
                repo_id, 
                open_date_id as date_id, 
                sum(iss) as iss
            from iss_agg 
            group by repo_id, open_date_id
        ) as io
            using(repo_id, date_id)

        full join (
            select 
                repo_id, 
                close_date_id as date_id, 
                sum(iss) as iss
            from iss_agg 
            group by repo_id, close_date_id
        ) as ic
            using(repo_id, date_id)
    )

    select
        cast(activity_id            as string) as activity_id,
        cast(repo_id                as string) as repo_id,
        cast(date_id                as int   ) as date_id,
        cast(commits                as bigint) as commits,
        cast(distinct_committers    as bigint) as distinct_committers,
        cast(prs_opened             as bigint) as prs_opened,
        cast(prs_merged             as bigint) as prs_merged,
        cast(issues_opened          as bigint) as issues_opened,
        cast(issues_closed          as bigint) as issues_closed,
        cast(stars                  as bigint) as stars,
        cast(forks                  as bigint) as forks
    from prep
    where date_id is not null and repo_id is not null
