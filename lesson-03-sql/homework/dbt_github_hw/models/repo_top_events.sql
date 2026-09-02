WITH    events AS ( SELECT * FROM {{ ref("stg_events") }} )

    SELECT 
        event_type, 
        repo_name,
        event_count,
        ROW_NUMBER() OVER (PARTITION BY event_type ORDER BY event_count DESC, repo_name) as type_rank
    FROM (
        SELECT
            event_type, repo_name, count(*) AS event_count
        FROM events
        GROUP BY event_type, repo_name 
    )
    QUALIFY type_rank <= 5
