-- Крок 2: silver.commits. Специфікація: ../../SPEC.md → «Крок 2».
-- Джерело: {{ ref('events') }}, лише PushEvent.
-- from_json(payload, PUSH_SCHEMA) → explode масиву commits → commit grain. PUSH_SCHEMA = var('push_schema').
-- Дедуп: один рядок на commit_sha, найраніший pushed_at.
-- Колонки: commit_sha, repo_name, pushed_by, branch, author_name, author_email, message,
--          is_distinct, pushed_at, is_merge_commit, message_subject, message_length
-- Пастка: `distinct` — reserved word, у DDL-схемі та доступі до поля потрібні backticks.

-- TODO: замініть заглушку на запит згідно зі SPEC.md
with
    base as (
        select 
            event_id,
            repo_name,
            actor_login,
            created_at,
            from_json(payload, "{{var('push_schema')}}") as payload_parsed
        from {{ ref('events') }}
        where event_type = 'PushEvent'
    ),

    detailed as (
        select 
            event_id,
            repo_name,
            actor_login,
            created_at,
            regexp_replace(payload_parsed.ref, '^refs/heads/', '') as branch,
            explode(payload_parsed.commits) as com
        from base
    ),
    
    prep as (
        select
            cast(com.sha                        as string   )   as commit_sha,
            cast(repo_name                      as string   )   as repo_name,
            cast(actor_login                    as string   )   as pushed_by,
            cast(branch                         as string   )   as branch,
            cast(com.author.name                as string   )   as author_name,
            cast(com.author.email               as string   )   as author_email,
            cast(com.message                    as string   )   as message,
            cast(com.`distinct`                 as boolean  )   as is_distinct,
            cast(created_at                     as timestamp)   as pushed_at,
            cast(com.message like 'Merge %'     as boolean  )   as is_merge_commit,
            cast(split(com.message, '\n')[0]    as string   )   as message_subject,
            cast(len(com.message)               as int      )   as message_length,
            row_number() over(partition by com.sha order by created_at, event_id) as rnk
        from detailed
    ),

    dedup as (
        select 
            commit_sha,
            repo_name,
            pushed_by,
            branch,
            author_name,
            author_email,
            message,
            is_distinct,
            pushed_at,
            is_merge_commit,
            message_subject,
            message_length
        from prep
        where rnk = 1
    )

    select * from dedup