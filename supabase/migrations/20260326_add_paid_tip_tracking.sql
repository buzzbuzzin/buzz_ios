-- Track paid tip payment artifacts separately from base booking payment.

ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS tip_payment_intent_id text,
ADD COLUMN IF NOT EXISTS tip_charge_id text,
ADD COLUMN IF NOT EXISTS tip_transfer_id text;
