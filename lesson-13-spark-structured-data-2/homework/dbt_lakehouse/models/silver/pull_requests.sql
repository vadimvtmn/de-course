-- Крок 3: silver.pull_requests. Специфікація: ../../SPEC.md → «Крок 3».
-- Джерело: {{ ref('events') }}, лише PullRequestEvent. from_json(payload, PR_SCHEMA), PR_SCHEMA = var('pr_schema').
-- Грануляція: один рядок на (repo_name, pr_number) — стан з ОСТАННЬОЇ за часом події (row_number desc).
-- Колонки: repo_name, pr_number, title, author_login, state, is_merged, is_draft, opened_at,
--          closed_at, merged_at, additions, deletions, changed_files, commits_count, comments,
--          review_comments, author_association, label_names, last_action, last_event_at, churn, hours_open

-- TODO: замініть заглушку на запит згідно зі SPEC.md

with
    base as (
        select 
            event_id,
            repo_name,
            actor_login,
            created_at,
            from_json(payload, "{{var('pr_schema')}}") as payload_parsed
        from {{ ref('events') }}
        where event_type = 'PullRequestEvent'
    ),

    rnked as (
        select 
            repo_name,
            created_at,
            payload_parsed.action as action,
            payload_parsed.number as pr_number,
            payload_parsed.pull_request as pr,
            row_number() over(partition by repo_name, payload_parsed.number order by created_at desc, event_id desc) as rnk
        from base
        where 
    ),

    prep as (
        select 
            cast(repo_name             as string        ) as repo_name,
            cast(pr_number             as int           ) as pr_number,
            cast(pr.title              as string        ) as title,
            cast(pr.user.login         as string        ) as author_login,
            cast(pr.state              as string        ) as state,
            cast(pr.merged             as boolean       ) as is_merged,
            cast(pr.draft              as boolean       ) as is_draft,
            cast(pr.created_at         as timestamp     ) as opened_at,
            cast(pr.closed_at          as timestamp     ) as closed_at,
            cast(pr.merged_at          as timestamp     ) as merged_at,
            cast(pr.additions          as int           ) as additions,
            cast(pr.deletions          as int           ) as deletions,
            cast(pr.changed_files      as int           ) as changed_files,
            cast(pr.commits            as int           ) as commits_count,
            cast(pr.comments           as int           ) as comments,
            cast(pr.review_comments    as int           ) as review_comments,
            cast(pr.author_association as string        ) as author_association,
            cast(pr.labels.name        as array<string> ) as label_names,
            cast(action                as string        ) as last_action,
            cast(created_at            as timestamp     ) as last_event_at
        from rnked
        where rnk = 1
    )

    select 
        *,
        additions + deletions as churn,
        cast(timestampdiff(HOUR, coalesce(closed_at, last_event_at), opened_at) as double) as hours_open
    from prep
