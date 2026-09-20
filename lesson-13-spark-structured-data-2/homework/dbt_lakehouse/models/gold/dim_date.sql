-- Крок 7: gold.dim_date. Специфікація: ../../SPEC.md → «Крок 7».
-- Згенерований безперервний календар (БЕЗ seed): explode(sequence(min, max, interval 1 day)).
-- Межі min/max — підзапитом по фактичних датах з {{ ref('commits') }}, {{ ref('pull_requests') }},
-- {{ ref('issues') }} (pushed_at / opened_at / merged_at / closed_at). Не хардкодьте.
-- Колонки: date_id (int yyyyMMdd), date_day (date), day_of_week, is_weekend, iso_week, year.

-- TODO: замініть заглушку на запит згідно зі SPEC.md

with 
    comm as (
        select 
            stack(
                2,
                min(pushed_at), 
                max(pushed_at)
            ) as ts
        from {{ ref('commits') }}
    ),

    pr as (
        select 
            stack(
                6,
                min(opened_at), 
                max(opened_at),
                min(closed_at), 
                max(closed_at),
                min(merged_at), 
                max(merged_at)
            ) as ts
        from {{ ref('pull_requests') }}
    ),

    iss as (
        select 
            stack(
                4,
                min(opened_at), 
                max(opened_at),
                min(closed_at), 
                max(closed_at)
            ) as ts
        from {{ ref('issues') }}
    ),

    ev as (
        select 
            stack(
                2,
                min(created_at),
                max(created_at)
            ) as ts
        from {{ ref('events') }}
    ),

    unioned as (
        select * from comm
        union all
        select * from pr
        union all
        select * from iss
        union all
        select * from ev
    )

    select
        cast(date_format(date_day, 'yyyyMMdd')  as int      ) as date_id,
        cast(date_day                           as date     ) as date_day,
        cast(dayofweek(date_day)                as int      ) as day_of_week, 
        cast((dayofweek(date_day) >= 6)         as boolean  ) as is_weekend,
        cast(weekofyear(date_day)               as int      ) as iso_week,
        cast(year(date_day)                     as int      ) as year
    from (
        select 
            explode(sequence(to_date(min(ts)), to_date(max(ts)), interval 1 day)) as date_day
        from unioned
    )
