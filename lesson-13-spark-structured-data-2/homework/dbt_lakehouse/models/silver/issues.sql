-- Крок 4: silver.issues. Специфікація: ../../SPEC.md → «Крок 4».
-- Джерело: {{ ref('events') }}, типи IssuesEvent ТА IssueCommentEvent (обидва несуть issue{}).
-- from_json(payload, ISSUE_SCHEMA), ISSUE_SCHEMA = var('issue_schema').
-- Грануляція: один рядок на (repo_name, issue_number) — стан з останньої за часом події.
-- Колонки: repo_name, issue_number, title, author_login, state, opened_at, closed_at,
--          comments, label_names, comment_events_seen, last_event_at, hours_to_close

-- TODO: замініть заглушку на запит згідно зі SPEC.md
with
    base as (
        select 
            event_id,
            repo_name,
            actor_login,
            created_at,
            event_type,
            from_json(payload, "{{var('issue_schema')}}") as payload_parsed
        from {{ ref('events') }}
        where event_type in ('IssuesEvent', 'IssueCommentEvent')
    ),

    rnked as (
        select 
            *,
            payload_parsed.issue as iss,
            row_number() over(partition by repo_name, payload_parsed.issue.number order by created_at desc, event_id desc) as rnk
        from base
    ),

    comm_events_by_cnt as (
        select 
            repo_name,
            iss.number      as issue_number,
            count(*)        as cnt
        from rnked
        where event_type = 'IssueCommentEvent'
        group by repo_name, issue_number
    ),

    prep as (
        select 
            cast(repo_name          as string       ) as repo_name,
            cast(iss.number         as int          ) as issue_number,
            cast(iss.title          as string       ) as title,
            cast(iss.user.login     as string       ) as author_login,
            cast(iss.state          as string       ) as state,
            cast(iss.created_at     as timestamp    ) as opened_at,
            cast(iss.closed_at      as timestamp    ) as closed_at,
            cast(iss.comments       as int          ) as comments,
            cast(iss.labels.name    as array<string>) as label_names,
            cast(created_at         as timestamp    ) as last_event_at
        from rnked
        where rnk = 1
    )

    select 
        p.*,
        cast(
            if(
                state = "close",
                timestampdiff(HOUR, p.closed_at, p.opened_at),
                null
            ) as double
        ) as hours_to_close,
        cast(c.cnt as bigint) as comment_events_seen
    from prep as p
    left join comm_events_by_cnt as c 
        using(repo_name, issue_number)

