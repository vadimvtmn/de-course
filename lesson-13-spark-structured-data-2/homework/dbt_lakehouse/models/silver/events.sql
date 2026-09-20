{{ config(materialized='incremental', incremental_strategy='append') }}

-- Крок 1: silver.events. Специфікація: ../../SPEC.md → «Крок 1».
-- Джерело: {{ source('bronze', 'raw_events') }}. payload несемо далі сирим рядком — from_json у кроках 2–4.
-- Колонки: event_id, event_type, actor_login, repo_name, repo_owner, created_at,
--          payload, _ingested_at, _source_file
-- Фільтри: 6 типів подій; public = true (NULL відкинути); event_id/repo_name/created_at не null; дедуп по event_id.
-- incremental (append): у is_incremental()-гілці брати лише рядки з _ingested_at > max(_ingested_at) у {{ this }}.

-- TODO: замініть заглушку на запит згідно зі SPEC.md

with 
    base as (
        select
            cast(id                                 as string   ) as event_id,
            cast(type                               as string   ) as event_type,
            cast(actor.login                        as string   ) as actor_login,
            cast(repo.name                          as string   ) as repo_name,
            cast(substring_index(repo.name, "/", 1) as string   ) as repo_owner,
            cast(created_at                         as timestamp) as created_at,
            cast(payload                            as string   ) as payload,
            cast(_ingested_at                       as timestamp) as _ingested_at,
            cast(_source_file                       as string   ) as _source_file
        from {{ source('bronze', 'raw_events') }}
        where 
            type in ("PushEvent", "PullRequestEvent", "IssuesEvent", "IssueCommentEvent", "WatchEvent", "ForkEvent")
            and ifnull(public, false) = true
            and id is not null 
            and repo.name  is not null 
            and created_at is not null
    ),

    filter_period as (
        select 
            *,
            row_number() over(partition by event_id order by created_at desc) as rnk
        from base
        {% if is_incremental() %}
            where _ingested_at > (select max(_ingested_at) from {{ this }}) 
        {% endif %}

    ),

    dedup as (
        select 
            event_id, 
            event_type, 
            actor_login, 
            repo_name, 
            repo_owner, 
            created_at, 
            payload, 
            _ingested_at, 
            _source_file
        from filter_period
        where rnk = 1
    )

    select * from dedup