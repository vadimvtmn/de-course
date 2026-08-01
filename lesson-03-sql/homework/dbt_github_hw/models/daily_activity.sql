WITH    events AS ( SELECT * FROM {{ ref("stg_events") }} )

    SELECT 
        event_date, 
        events,
        SUM(events) OVER (ORDER BY event_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_events
    FROM (
        SELECT
            event_date, count(*) AS events
        FROM events
        GROUP BY event_date 
    )
