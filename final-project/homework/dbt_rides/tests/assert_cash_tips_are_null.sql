-- Готівкові поїздки приходять БЕЗ чайових: tip_amount = NULL, а не 0.
-- у безготівкових чайові відомі завжди (можуть бути 0, але не NULL).

select ride_id, payment_method, tip_amount
from {{ ref('rides') }}
where status = 'completed'
  and payment_method is not null
  and (payment_method = 'cash') <> (tip_amount is null)
