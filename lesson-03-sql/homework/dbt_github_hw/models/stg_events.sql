{{ config(materialized='view') }}

WITH    sr AS ( SELECT * FROM read_parquet('{{ var("events_path") }}') )

    SELECT
        id::VARCHAR                     as id,
        event_type::VARCHAR             as event_type,
        created_at::TIMESTAMPTZ         as created_at,
        event_date::DATE                as event_date,
        actor_login::VARCHAR            as actor_login,
        repo_name::VARCHAR              as repo_name,
        payload_commit_count::BIGINT    as payload_commit_count,
        payload_action::VARCHAR         as payload_action,
        payload_ref::VARCHAR            as payload_ref 
    FROM sr
    WHERE event_type IN ('PushEvent', 'IssuesEvent', 'PullRequestEvent', 'WatchEvent', 'IssueCommentEvent')
        AND actor_login NOT LIKE '%[bot]'
        AND NOT (event_type = 'PushEvent' AND payload_commit_count = 0)


