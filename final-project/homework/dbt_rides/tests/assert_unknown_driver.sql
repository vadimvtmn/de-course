-- 'unknown' — лише для поїздок, скасованих до прийняття. Прийнята поїздка з 'unknown'
select ride_id, driver_key, accepted_at
from {{ ref('fact_ride') }}
where (driver_key = 'unknown') <> (accepted_at is null)