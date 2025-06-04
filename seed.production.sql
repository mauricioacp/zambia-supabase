-- Production seed data - Essential reference data only
-- No test users or test data

BEGIN;

-- ==========================================
-- 1. Location Entities - Essential Data
-- ==========================================

-- Countries
INSERT INTO countries (id, name, code)
VALUES (uuid_generate_v4(), 'Argentina', 'AR'),
       (uuid_generate_v4(), 'Bolivia', 'BO'),
       (uuid_generate_v4(), 'Brasil', 'BR'),
       (uuid_generate_v4(), 'Colombia', 'CO'),
       (uuid_generate_v4(), 'Chile', 'CL'),
       (uuid_generate_v4(), 'Costa Rica', 'CR'),
       (uuid_generate_v4(), 'Ecuador', 'EC'),
       (uuid_generate_v4(), 'España', 'ES'),
       (uuid_generate_v4(), 'México', 'MX'),
       (uuid_generate_v4(), 'Perú', 'PE'),
       (uuid_generate_v4(), 'Internacional-Webinar', 'I_WB'),
       (uuid_generate_v4(), 'Uruguay', 'UY');

-- Your headquarters (copy from seed.sql)
-- INSERT INTO headquarters ...

-- ==========================================
-- 2. Core Configuration - Essential Data
-- ==========================================

-- Roles (copy from seed.sql)
-- INSERT INTO roles ...

-- Event types (copy from seed.sql)
-- INSERT INTO event_types ...

-- ==========================================
-- 3. Initial Season for Production
-- ==========================================

-- Add one active season for the main headquarter
INSERT INTO seasons (id, name, headquarter_id, start_date, end_date, status)
SELECT uuid_generate_v4(),
       'Production Season 2025',
       (SELECT id FROM headquarters WHERE name = 'Mendoza' LIMIT 1),
       '2025-01-01',
       '2025-12-31',
       'active';

COMMIT;