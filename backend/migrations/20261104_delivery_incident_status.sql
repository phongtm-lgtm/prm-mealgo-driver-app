-- Hibernate schema-update does not expand existing PostgreSQL enum CHECK constraints.
-- Run once against an existing database before using delivery incident APIs.
BEGIN;
ALTER TABLE deliveries DROP CONSTRAINT IF EXISTS deliveries_status_check;
ALTER TABLE deliveries ADD CONSTRAINT deliveries_status_check CHECK (status IN
 ('PENDING_ASSIGNMENT','ASSIGNED','AT_PICKUP','PICKED_UP','AT_DROPOFF','DELIVERED','FAILED','CANCELLED'));
ALTER TABLE delivery_assignments DROP CONSTRAINT IF EXISTS delivery_assignments_status_check;
ALTER TABLE delivery_assignments ADD CONSTRAINT delivery_assignments_status_check CHECK (status IN
 ('OFFERED','ACCEPTED','REJECTED','EXPIRED','COMPLETED','FAILED','RELEASED','CANCELLED'));
COMMIT;
