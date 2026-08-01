-- =====================================================================
-- TASK 5 — starred_repos_without_push (12 балів). Специфікація: ../../MODELS.md → «starred_repos_without_push».
-- Репозиторії зі зіркою (WatchEvent), але без жодного PushEvent: anti-join (NOT EXISTS).
-- Контракт колонок нижче; заглушка повертає 0 рядків.
-- =====================================================================
WITH    events AS ( SELECT * FROM {{ ref("stg_events") }} )

    SELECT 
        repo_name
    FROM 
        (SELECT DISTINCT repo_name FROM events WHERE event_type = 'WatchEvent') AS w
    LEFT JOIN 
        (SELECT DISTINCT repo_name FROM events WHERE event_type = 'PushEvent') AS p 
        USING(repo_name)
    WHERE p.repo_name IS NULL

