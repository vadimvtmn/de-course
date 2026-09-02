WITH    events      AS ( SELECT * FROM {{ ref("stg_events") }} ),
        categories  AS ( SELECT * FROM {{ ref("event_categories") }} ),
        calendar    AS ( SELECT * FROM {{ ref("calendar") }} )

    SELECT
        e.event_date,
        cal.is_weekend,
        cat.category,
        count(*)                        AS events,
        count(DISTINCT e.repo_name)     AS distinct_repos,
        count(DISTINCT e.actor_login)   AS distinct_actors
    FROM events     AS e 
    JOIN categories AS cat 
        USING(event_type)
    JOIN calendar   AS cal 
        ON cal.day = e.event_date
    GROUP BY e.event_date, cal.is_weekend, cat.category

