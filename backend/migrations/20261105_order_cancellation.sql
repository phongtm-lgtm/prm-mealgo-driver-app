-- Existing PostgreSQL databases: retain historical orders and expand Hibernate's enum check.
BEGIN;
ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS cancellation_code varchar(255);
ALTER TABLE delivery_incidents DROP CONSTRAINT IF EXISTS delivery_incidents_reason_check;
ALTER TABLE delivery_incidents ADD CONSTRAINT delivery_incidents_reason_check CHECK (reason IN
 ('PERSONAL','RESTAURANT_DELAY','RESTAURANT_CLOSED','VEHICLE_BREAKDOWN','BAD_WEATHER','CUSTOMER_UNREACHABLE'));
COMMIT;
