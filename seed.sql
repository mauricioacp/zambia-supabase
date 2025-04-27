-- This file contains seed data for the Akademia database
-- It depends on the schema being already created
-- Execute schema.sql before running this file

BEGIN;

-- ==========================================
-- 1. Location Entities - Seed Data
-- ==========================================

-- Seed Countries
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

-- Seed Headquarters
-- Argentina (AR)
INSERT INTO headquarters (name, country_id)
VALUES ('Mendoza', (SELECT id FROM countries WHERE code = 'AR')),
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
VALUES ('Barcelona', (SELECT id FROM countries WHERE code = 'ES')),
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
VALUES ('Quito', (SELECT id FROM countries WHERE code = 'EC')),
       ('Ambato', (SELECT id FROM countries WHERE code = 'EC')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'EC'));

-- México (MX)
INSERT INTO headquarters (name, country_id)
VALUES ('Ciudad de México', (SELECT id FROM countries WHERE code = 'MX')),
       ('Monterrey', (SELECT id FROM countries WHERE code = 'MX')),
       ('Tepatitlan de Morelos', (SELECT id FROM countries WHERE code = 'MX')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'MX'));

-- Perú (PE)
INSERT INTO headquarters (name, country_id)
VALUES ('Lima', (SELECT id FROM countries WHERE code = 'PE'));

-- Colombia (CO)
INSERT INTO headquarters (name, country_id)
VALUES ('Medellín', (SELECT id FROM countries WHERE code = 'CO')),
       ('Cali', (SELECT id FROM countries WHERE code = 'CO')),
       ('Bogotá', (SELECT id FROM countries WHERE code = 'CO')),
       ('Bucaramanga', (SELECT id FROM countries WHERE code = 'CO')),
       ('Aburra Sur', (SELECT id FROM countries WHERE code = 'CO')),
       ('ISA', (SELECT id FROM countries WHERE code = 'CO')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'CO'));

-- Bolivia (BO)
INSERT INTO headquarters (name, country_id)
VALUES ('Santa Cruz', (SELECT id FROM countries WHERE code = 'BO')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'BO'));

-- Uruguay (UY)
INSERT INTO headquarters (name, country_id)
VALUES ('Montevideo', (SELECT id FROM countries WHERE code = 'UY')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'UY'));

-- Chile (CL)
INSERT INTO headquarters (name, country_id)
VALUES ('Santiago', (SELECT id FROM countries WHERE code = 'CL')),
       ('Konsejo Akademíko', (SELECT id FROM countries WHERE code = 'CL'));

-- Webinar (país Internacional-Webinar, I_WB)
INSERT INTO headquarters (name, country_id)
VALUES ('Webinar Septiembre', (SELECT id FROM countries WHERE code = 'I_WB')),
       ('Webinar Marzo', (SELECT id FROM countries WHERE code = 'I_WB'));


-- ==========================================
-- 2. People and Roles - Seed Data
-- ==========================================

-- Seed Roles
INSERT INTO roles (id, code, name, description, status, level)
VALUES (uuid_generate_v4(), 'superadmin', 'Super administrador',
        'Administrador super usuario', 'active', 100),
       (uuid_generate_v4(), 'general_director', 'Director General',
        'Coordinador General de la Akademia a nivel internacional, gestiona el Konsejo y se mantiene en contacto con el Fundador',
        'active', 95),
       (uuid_generate_v4(), 'executive_leader', 'Líder Ejecutivo',
        'Lidera el equipo ejecutivo, analiza necesidades de gestión y optimiza procesos internos',
        'active', 90),
       (uuid_generate_v4(), 'pedagogical_leader', 'Líder Pedagógico',
        'Lidera el equipo pedagógico, asesora a las Akademias en temas pedagógicos y vela por el cumplimiento del programa',
        'active', 90),
       (uuid_generate_v4(), 'communication_leader', 'Líder de Comunicación',
        'Lidera el equipo de comunicación, gestiona la estrategia de comunicación y la imagen corporativa',
        'active', 90),
       (uuid_generate_v4(), 'coordination_leader', 'Líder de Koordinación',
        'Coordinador de todos los Koordinadores y su representante en el Konsejo',
        'active', 90),
       (uuid_generate_v4(), 'innovation_leader', 'Líder de Innovación',
        'Lidera el equipo de innovación, impulsa nuevos proyectos y metodologías para mejorar el programa',
        'active', 80),
       (uuid_generate_v4(), 'community_leader', 'Líder de Komunidad',
        'Lidera el equipo de Komunidad, genera vínculos entre miembros actuales y antiguos de La Akademia',
        'active', 80),
       (uuid_generate_v4(), 'utopik_foundation_user', 'Fundación Utópika',
        'Usuario de la Fundación Utópika',
        'active', 80),
       (uuid_generate_v4(), 'coordinator', 'Koordinador',
        'Nexo entre el Konsejo y las Akademias locales asignadas. Apoyo y supervisión de sedes',
        'active', 80),
       (uuid_generate_v4(), 'legal_advisor', 'Asesor Legal',
        'Lidera el Comité ético y asesora al Konsejo en temas legales',
        'active', 80),
       (uuid_generate_v4(), 'konsejo_member',
        'Miembro del Konsejo de Dirección',
        'Miembro del consejo de dirección con capacidad de toma de decisiones estratégicas',
        'active', 80),
       (uuid_generate_v4(), 'headquarter_manager', 'Director/a Local',
        'Responsable de la dirección general de una sede',
        'active', 50),
       (uuid_generate_v4(), 'pedagogical_manager',
        'Director/a Pedagógico Local',
        'Responsable del área pedagógica de una sede',
        'active', 50),
       (uuid_generate_v4(), 'communication_manager',
        'Director/a de Comunicación Local',
        'Responsable del área de comunicación de una sede',
        'active', 50),
       (uuid_generate_v4(), 'companion_director',
        'Director/a de Acompañantes Local',
        'Responsable del área de acompañamiento de una sede',
        'active', 50),
       (uuid_generate_v4(), 'manager_assistant', 'Asistente a la dirección',
        'Colaborador Asistente en la dirección de una sede', 'active', 30),
       (uuid_generate_v4(), 'companion', 'Acompañante',
        'Persona que acompaña a los alumnos en su proceso de aprendizaje',
        'active', 20),
       (uuid_generate_v4(), 'facilitator', 'Facilitador',
        'Facilitador de actividades y talleres', 'active', 20),
       (uuid_generate_v4(), 'student', 'Alumno',
        'Estudiante registrado en el programa', 'active', 1);


-- -- ==========================================
-- -- 3. Seasons - Seed Data (todo seasons should have a manager id, so we need to create users -> collaborators -> seasons)
-- -- ==========================================

-- -- Add one season for each headquarter
-- INSERT INTO seasons (id, name, headquarter_id, start_date, end_date, status)
-- SELECT uuid_generate_v4(),
--        headquarters.name || ' - Edición 2024-2025',
--        headquarters.id,
--        '2024-09-10',
--        '2025-05-15',
--        'active'
-- FROM headquarters;


COMMIT;
