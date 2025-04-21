-- This file contains seed data for the Akademia database
-- It depends on the schema being already created
-- Execute schema.sql before running this file

BEGIN;

-- ==========================================
-- 1. Location Entities - Seed Data
-- ==========================================

-- Seed Countries
INSERT INTO countries (id, name, code)
VALUES
    (uuid_generate_v4(),'Argentina', 'AR'),
    (uuid_generate_v4(),'Bolivia', 'BO'),
    (uuid_generate_v4(),'Brasil', 'BR'),
    (uuid_generate_v4(),'Colombia', 'CO'),
    (uuid_generate_v4(),'Chile', 'CL'),
    (uuid_generate_v4(),'Costa Rica', 'CR'),
    (uuid_generate_v4(),'Ecuador', 'EC'),
    (uuid_generate_v4(),'España', 'ES'),
    (uuid_generate_v4(),'México', 'MX'),
    (uuid_generate_v4(),'Perú', 'PE'),
    (uuid_generate_v4(),'Internacional-Webinar', 'I_WB'),
    (uuid_generate_v4(),'Uruguay', 'UY');

-- Seed Headquarters
-- Argentina (AR)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Mendoza', (SELECT id FROM countries WHERE code = 'AR')),
  ('San Rafael', (SELECT id FROM countries WHERE code = 'AR')),
  ('Buenos Aires', (SELECT id FROM countries WHERE code = 'AR')),
  ('Santa Fe', (SELECT id FROM countries WHERE code = 'AR')),
  ('Santiago del Estero', (SELECT id FROM countries WHERE code = 'AR')),
  ('Río Cuarto', (SELECT id FROM countries WHERE code = 'AR')),
  ('Catamarca', (SELECT id FROM countries WHERE code = 'AR')),
  ('Mar de Plata', (SELECT id FROM countries WHERE code = 'AR')),
  ('Córdoba', (SELECT id FROM countries WHERE code = 'AR')),
  ('General Pico, La Pampa', (SELECT id FROM countries WHERE code = 'AR')),
  ('San Fernando, Bs As', (SELECT id FROM countries WHERE code = 'AR')),
  ('La Plata', (SELECT id FROM countries WHERE code = 'AR')),
  ('Villa María', (SELECT id FROM countries WHERE code = 'AR')),
  ('Resistencia', (SELECT id FROM countries WHERE code = 'AR')),
  ('San Juan', (SELECT id FROM countries WHERE code = 'AR')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'AR'));

-- España (ES)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Barcelona', (SELECT id FROM countries WHERE code = 'ES')),
  ('Cambrils', (SELECT id FROM countries WHERE code = 'ES')),
  ('Girona', (SELECT id FROM countries WHERE code = 'ES')),
  ('Granollers', (SELECT id FROM countries WHERE code = 'ES')),
  ('Mataró', (SELECT id FROM countries WHERE code = 'ES')),
  ('Sabadell', (SELECT id FROM countries WHERE code = 'ES')),
  ('Lleida', (SELECT id FROM countries WHERE code = 'ES')),
  ('Tarragona', (SELECT id FROM countries WHERE code = 'ES')),
  ('Sant Boi de Llobregat', (SELECT id FROM countries WHERE code = 'ES')),
  ('Vic', (SELECT id FROM countries WHERE code = 'ES')),
  ('La Senia', (SELECT id FROM countries WHERE code = 'ES')),
  ('Reus', (SELECT id FROM countries WHERE code = 'ES')),
  ('Elche', (SELECT id FROM countries WHERE code = 'ES')),
  ('Ibiza', (SELECT id FROM countries WHERE code = 'ES')),
  ('Mallorca', (SELECT id FROM countries WHERE code = 'ES')),
  ('Murcia', (SELECT id FROM countries WHERE code = 'ES')),
  ('Valencia', (SELECT id FROM countries WHERE code = 'ES')),
  ('Valencia Nómada Upv', (SELECT id FROM countries WHERE code = 'ES')),
  ('Valencia Catarroja', (SELECT id FROM countries WHERE code = 'ES')),
  ('Tenerife', (SELECT id FROM countries WHERE code = 'ES')),
  ('Cartagena', (SELECT id FROM countries WHERE code = 'ES')),
  ('Alicante', (SELECT id FROM countries WHERE code = 'ES')),
  ('Cáceres', (SELECT id FROM countries WHERE code = 'ES')),
  ('Bilbao', (SELECT id FROM countries WHERE code = 'ES')),
  ('Burgos', (SELECT id FROM countries WHERE code = 'ES')),
  ('Córdoba', (SELECT id FROM countries WHERE code = 'ES')),
  ('Donostia/San Sebastián', (SELECT id FROM countries WHERE code = 'ES')),
  ('Granada', (SELECT id FROM countries WHERE code = 'ES')),
  ('Jaén', (SELECT id FROM countries WHERE code = 'ES')),
  ('Madrid', (SELECT id FROM countries WHERE code = 'ES')),
  ('Málaga', (SELECT id FROM countries WHERE code = 'ES')),
  ('Valladolid', (SELECT id FROM countries WHERE code = 'ES')),
  ('Zaragoza', (SELECT id FROM countries WHERE code = 'ES')),
  ('Sevilla', (SELECT id FROM countries WHERE code = 'ES')),
  ('Coruña', (SELECT id FROM countries WHERE code = 'ES')),
  ('Almería', (SELECT id FROM countries WHERE code = 'ES')),
  ('Linares', (SELECT id FROM countries WHERE code = 'ES')),
  ('Pisuerga', (SELECT id FROM countries WHERE code = 'ES')),
  ('Logroño', (SELECT id FROM countries WHERE code = 'ES')),
  ('Gijón', (SELECT id FROM countries WHERE code = 'ES')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'ES'));

-- Ecuador (EC)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Quito', (SELECT id FROM countries WHERE code = 'EC')),
  ('Ambato', (SELECT id FROM countries WHERE code = 'EC')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'EC'));

-- México (MX)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Ciudad de México', (SELECT id FROM countries WHERE code = 'MX')),
  ('Monterrey', (SELECT id FROM countries WHERE code = 'MX')),
  ('Tepatitlan de Morelos', (SELECT id FROM countries WHERE code = 'MX')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'MX'));

-- Perú (PE)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Lima', (SELECT id FROM countries WHERE code = 'PE'));

-- Colombia (CO)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Medellín', (SELECT id FROM countries WHERE code = 'CO')),
  ('Cali', (SELECT id FROM countries WHERE code = 'CO')),
  ('Bogotá', (SELECT id FROM countries WHERE code = 'CO')),
  ('Bucaramanga', (SELECT id FROM countries WHERE code = 'CO')),
  ('Aburra Sur', (SELECT id FROM countries WHERE code = 'CO')),
  ('ISA', (SELECT id FROM countries WHERE code = 'CO')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'CO'));

-- Bolivia (BO)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Santa Cruz', (SELECT id FROM countries WHERE code = 'BO')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'BO'));

-- Uruguay (UY)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Montevideo', (SELECT id FROM countries WHERE code = 'UY')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'UY'));

-- Chile (CL)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Santiago', (SELECT id FROM countries WHERE code = 'CL')),
  ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'CL'));

-- Webinar (país Internacional-Webinar, I_WB)
INSERT INTO headquarters (name, country_id)
VALUES
  ('Webinar Septiembre', (SELECT id FROM countries WHERE code = 'I_WB')),
  ('Webinar Marzo', (SELECT id FROM countries WHERE code = 'I_WB'));


-- ==========================================
-- 2. People and Roles - Seed Data
-- ==========================================

-- Seed Roles
INSERT INTO roles (id, code, name, description, status)
VALUES
  (uuid_generate_v4(), 'headquarter_manager', 'Director/a Local', 'Responsable de la dirección de una sede', 'active'),
  (uuid_generate_v4(), 'manager_assistant', 'Asistente a la dirección', 'Colaborador Asistente en la dirección de una sede', 'active'),
  (uuid_generate_v4(), 'companion_manager', 'Coordinador de acompañantes', 'Coordinador de los acompañantes en una sede', 'active'),
  (uuid_generate_v4(), 'konsejo_member', 'Miembro del Konsejo de Dirección', 'Miembro del consejo de dirección con capacidad de toma de decisiones estratégicas', 'active'),
  (uuid_generate_v4(), 'superadmin', 'Super administrador', 'Administrador super usuario', 'active'),
  (uuid_generate_v4(), 'group_leader', 'Líder de área', 'Ejcutivo, pedagógico, comunicación, innovación, coordinadores', 'active'),
  (uuid_generate_v4(), 'coordinator', 'Coordinador', 'Coordinador de un área', 'active'),
  (uuid_generate_v4(), 'companion', 'Acompañante', 'Persona que acompaña a los alumnos en su proceso de aprendizaje', 'active'),
  (uuid_generate_v4(), 'facilitator', 'Facilitador', 'Facilitador de actividades y talleres', 'active'),
  (uuid_generate_v4(), 'student', 'Alumno', 'Estudiante registrado en el programa', 'active');

-- Test Users: Only for development
-- Uncomment this section for local development if needed
/*
-- Create test users in auth schema if in development mode
DO $$
BEGIN
  IF current_setting('app.environment', TRUE)::text = 'development' THEN
    -- This function only works in local development with Supabase
    PERFORM supabase_auth.create_user(
      email := 'admin@example.com',
      password := 'password123',
      email_confirmed := true,
      data := '{"name": "Admin User", "role": "admin"}'::jsonb
    );
    
    -- Insert agreements with test user
    INSERT INTO agreements (role_id, user_id, headquarter_id, status, email, name, last_name)
    SELECT 
      (SELECT id FROM roles WHERE code = 'superadmin'), 
      (SELECT id FROM auth.users WHERE email = 'admin@example.com'), 
      (SELECT id FROM headquarters LIMIT 1), 
      'active', 
      'admin@example.com', 
      'Admin', 
      'User';
  END IF;
END
$$;
*/

COMMIT;