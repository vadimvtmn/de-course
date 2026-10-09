-- silver.rides — ЕТАП 2. Grain: одна поїздка (ride_id). SPEC.md, розділ 4.3.
--   * incremental, unique_key='ride_id', delete+insert
--   * перебудовуйте поїздки, яких торкнулися НОВІ події, з УСІЄЇ їхньої історії в ref('events')
--   * поїздка існує, коли прийшла її ride_requested; порядок прибуття подій байдужий
--   * status, фактична зона (перекриває заявлену), wait_seconds, trip_seconds, суми з ride_completed
--   * _ingested_at = максимум _ingested_at усіх подій поїздки

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='ride_id'
) }}

with
{% if is_incremental() %}
touched as (
    -- поїздки, яких торкнулися нові події
    select distinct ride_id
    from {{ ref('events') }}
    where _ingested_at > {{ high_watermark() }}
),
{% endif %}

base as (
    -- уся історія зачеплених поїздок
    select * from {{ ref('events') }}
    {% if is_incremental() %}
    where ride_id in (select ride_id from touched)
    {% endif %}
),

ride_ingested as (
    select ride_id, max(_ingested_at) as _ingested_at
    from base
    group by ride_id
),

ride_requested as (
    select
        ride_id,
        occurred_at,
        payload->'rider'->>'id'                  as rider_id,
        payload->'rider'->>'platform'            as rider_platform,
        payload->'rider'->>'app_version'         as app_version,
        payload->>'requested_vehicle'            as requested_vehicle,
        (payload->'pickup'->>'zone_id')::int     as pickup_zone_id,
        (payload->'dropoff'->>'zone_id')::int    as dropoff_zone_id,
        (payload->>'surge_estimate')::numeric    as surge_estimate
    from base
    where event_type = 'ride_requested'
),

ride_accepted as (
    select
        ride_id,
        occurred_at,
        payload->'driver'->>'id' as driver_id
    from base
    where event_type = 'ride_accepted'
),

ride_started as (
    select
        ride_id,
        occurred_at,
        payload->'driver'->>'id'              as driver_id,
        (payload->'pickup'->>'zone_id')::int  as pickup_zone_id
    from base
    where event_type = 'ride_started'
),

ride_completed as (
    select
        ride_id,
        occurred_at,
        payload->'driver'->>'id'                              as driver_id,
        (payload->'dropoff'->>'zone_id')::int                 as dropoff_zone_id,
        (payload->>'distance_km')::numeric(8,2)               as distance_km,
        (payload->'fare'->>'surge_multiplier')::numeric(4,2)  as surge_multiplier,
        (payload->'fare'->>'amount')::numeric(10,2)           as fare_amount,
        (payload->'fare'->>'tolls')::numeric(10,2)            as tolls_amount,
        (payload->'fare'->>'tip')::numeric(10,2)              as tip_amount,
        (payload->'fare'->>'total')::numeric(10,2)            as total_amount,
        payload->'fare'->>'currency'                          as currency
    from base
    where event_type = 'ride_completed'
),

ride_cancelled as (
    select
        ride_id,
        occurred_at,
        payload->>'cancelled_by' as cancelled_by,
        payload->>'reason'       as cancel_reason,
        payload->>'stage'        as cancel_stage
    from base
    where event_type = 'ride_cancelled'
),

payment_captured as (
    select
        ride_id,
        occurred_at,
        payload->'payment'->>'method'                    as payment_method,
        payload->'payment'->>'psp_reference'             as psp_reference,
        (payload->'payment'->>'amount')::numeric(10,2)   as payment_amount
    from base
    where event_type = 'payment_captured'
)

select
    req.ride_id,
    req.rider_id,
    req.rider_platform,
    req.app_version,
    req.requested_vehicle,
    coalesce(acc.driver_id, sta.driver_id, com.driver_id) as driver_id,
    case
        when com.ride_id is not null then 'completed'
        when can.ride_id is not null then 'cancelled'
        when sta.ride_id is not null then 'in_progress'
        when acc.ride_id is not null then 'accepted'
        else 'requested'
    end as status,
    req.occurred_at as requested_at,
    acc.occurred_at as accepted_at,
    sta.occurred_at as started_at,
    com.occurred_at as completed_at,
    can.occurred_at as cancelled_at,
    pay.occurred_at as paid_at,
    coalesce(sta.pickup_zone_id, req.pickup_zone_id)   as pickup_zone_id,
    coalesce(com.dropoff_zone_id, req.dropoff_zone_id) as dropoff_zone_id,
    extract(epoch from acc.occurred_at - req.occurred_at)::int as wait_seconds,
    extract(epoch from com.occurred_at - sta.occurred_at)::int as trip_seconds,
    req.surge_estimate,
    com.distance_km,
    com.surge_multiplier,
    com.fare_amount,
    com.tolls_amount,
    com.tip_amount,
    com.total_amount,
    com.currency,
    can.cancelled_by,
    can.cancel_reason,
    can.cancel_stage,
    pay.payment_method,
    pay.psp_reference,
    pay.payment_amount,
    ing._ingested_at,
    '{{ run_started_at }}'::timestamptz as _loaded_at
from ride_requested as req
join ride_ingested as ing on ing.ride_id = req.ride_id
left join ride_accepted    as acc on acc.ride_id = req.ride_id
left join ride_started     as sta on sta.ride_id = req.ride_id
left join ride_completed   as com on com.ride_id = req.ride_id
left join ride_cancelled   as can on can.ride_id = req.ride_id
left join payment_captured as pay on pay.ride_id = req.ride_id