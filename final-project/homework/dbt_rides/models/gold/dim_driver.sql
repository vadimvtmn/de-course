-- gold.dim_driver — ЕТАП 2. Grain: водій. SPEC.md, розділ 4.4.
--   * incremental, unique_key='driver_key', delete+insert; за подіями ride_accepted у ref('events')
--   * «останній» рейтинг — за occurred_at; перераховуйте водія з УСІЄЇ його історії, не з батча
--   * плюс член driver_key = 'unknown' (поїздки, скасовані до прийняття)

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='driver_key'
) }}

with accepted as (
    select 
        event_id,
        payload->'driver'->>'id'                    as driver_key,
        payload->'driver'->'vehicle'->>'type'       as vehicle_type,
        payload->'driver'->'vehicle'->>'medallion'  as medallion,
        payload->'driver'->>'rating'::numeric(3,2)  as rating,
        occurred_at,
        _ingested_at
    from {{ ref('events') }}
    where event_type = 'ride_accepted'
),

{% if is_incremental() %}
touched as (
    select distinct driver_key
    from accepted
    where _ingested_at > {{ high_watermark() }}
),
{% endif %}

base as (
    select * from accepted
    {% if is_incremental() %}
    where driver_key in (select driver_key from touched)
    {% endif %}
),
rnked as (
    select 
        *,
        row_number() over(partiton by driver_key order by occurred_at desc) as r
    from base
    group by driver_key
),

ranked as (
    select
        *,
        row_number() over (
            partition by driver_key
            order by occurred_at desc, event_id desc
        ) as rn
    from base
),

agg as (
    select
        driver_key,
        min(occurred_at)  as first_seen_at,
        max(occurred_at)  as last_seen_at,
        max(_ingested_at) as _ingested_at
    from base
    group by driver_key
)

select
    r.driver_key,
    r.vehicle_type,
    r.medallion,
    r.rating as latest_rating,
    a.first_seen_at,
    a.last_seen_at,
    a._ingested_at,
    '{{ run_started_at }}'::timestamptz as _loaded_at
from ranked as r
join agg as a using (driver_key)
where r.rn = 1

union all

select
    'unknown'               as driver_key,
    'unknown'               as vehicle_type,
    null                    as medallion,
    null::numeric(3,2)      as latest_rating,
    null::timestamptz       as first_seen_at,
    null::timestamptz       as last_seen_at,
    null::timestamptz       as _ingested_at,
    '{{ run_started_at }}'::timestamptz as _loaded_at