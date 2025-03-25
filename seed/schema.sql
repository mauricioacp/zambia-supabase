-- This file contains the schema definitions for the Akademia database
-- It depends on the auth schema that comes pre-configured with Supabase
-- For local development, make sure Supabase auth is properly set up

BEGIN;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "moddatetime" SCHEMA extensions;

-- ==========================================
-- 1. Location Entities
-- ==========================================

-- Countries
CREATE TABLE countries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_countries
BEFORE UPDATE ON countries
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_countries_code ON countries(code);

-- Headquarters
CREATE TABLE headquarters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    country_id UUID REFERENCES countries(id) ON DELETE RESTRICT,
    address TEXT,
    contact_info JSONB DEFAULT '{}',
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_headquarters
BEFORE UPDATE ON headquarters
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_headquarters_country_id ON headquarters(country_id);

-- Seasons
CREATE TABLE seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE CASCADE,
    manager_id UUID NULL, -- Allow NULL during development
    start_date DATE,
    end_date DATE,
    status TEXT CHECK (status IN ('active', 'inactive', 'planning', 'completed')) DEFAULT 'planning',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_seasons
BEFORE UPDATE ON seasons
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_seasons_headquarter_id ON seasons(headquarter_id);
CREATE INDEX idx_seasons_manager_id ON seasons(manager_id);

-- ==========================================
-- 2. People and Roles
-- ==========================================

-- Roles
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    permissions JSONB DEFAULT '{}'
);

CREATE TRIGGER handle_updated_at_roles
BEFORE UPDATE ON roles
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_roles_code ON roles(code);

-- Agreements
CREATE TABLE agreements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID REFERENCES roles(id) ON DELETE RESTRICT,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NULL, -- Allow NULL for development
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    status TEXT CHECK (status IN ('active', 'inactive', 'prospect')) DEFAULT 'prospect',
    email TEXT NOT NULL,
    document_number TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    name TEXT,
    last_name TEXT,
    address TEXT,
    volunteering_agreement BOOLEAN DEFAULT FALSE,
    ethical_document_agreement BOOLEAN DEFAULT FALSE,
    mailing_agreement BOOLEAN DEFAULT FALSE,
    age_verification BOOLEAN DEFAULT FALSE,
    signature_data TEXT,
    UNIQUE (user_id, season_id, role_id)
);

CREATE TRIGGER handle_updated_at_agreements
BEFORE UPDATE ON agreements
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_agreements_role_id ON agreements(role_id);
CREATE INDEX idx_agreements_user_id ON agreements(user_id);
CREATE INDEX idx_agreements_headquarter_id ON agreements(headquarter_id);
CREATE INDEX idx_agreements_season_id ON agreements(season_id);
CREATE INDEX idx_agreements_email ON agreements(email);
CREATE INDEX idx_agreements_document_number ON agreements(document_number);
CREATE INDEX idx_agreements_phone ON agreements(phone);
CREATE INDEX idx_agreements_name ON agreements(name);
CREATE INDEX idx_agreements_last_name ON agreements(last_name);

-- Students
CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NULL, -- Allow NULL for development
    agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID REFERENCES seasons(id) ON DELETE RESTRICT,
    enrollment_date DATE,
    status TEXT CHECK (status IN ('active', 'prospect', 'graduated', 'inactive')) DEFAULT 'prospect',
    program_progress_comments JSONB
);

CREATE INDEX idx_students_user_id ON students(user_id);
CREATE INDEX idx_students_agreement_id ON students(agreement_id);
CREATE INDEX idx_students_headquarter_id ON students(headquarter_id);
CREATE INDEX idx_students_season_id ON students(season_id);

-- Collaborators
CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NULL, -- Allow NULL for development
    agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id) ON DELETE RESTRICT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    status TEXT CHECK (status IN ('active', 'inactive', 'standby')) DEFAULT 'inactive',
    start_date DATE,
    end_date DATE
);

CREATE INDEX idx_collaborators_user_id ON collaborators(user_id);
CREATE INDEX idx_collaborators_agreement_id ON collaborators(agreement_id);
CREATE INDEX idx_collaborators_role_id ON collaborators(role_id);
CREATE INDEX idx_collaborators_headquarter_id ON collaborators(headquarter_id);

-- ==========================================
-- 3. Operational Entities
-- ==========================================

-- Workshops
CREATE TABLE workshops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    facilitator_id UUID REFERENCES collaborators(id) ON DELETE SET NULL,
    capacity INTEGER,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_workshops
BEFORE UPDATE ON workshops
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_workshops_headquarter_id ON workshops(headquarter_id);

-- Events
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    location JSONB,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft'
);

CREATE TRIGGER handle_updated_at_events
BEFORE UPDATE ON events
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_events_headquarter_id ON events(headquarter_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_datetime ON events(start_datetime);

-- Processes
CREATE TABLE processes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),   
    name TEXT NOT NULL,
    description TEXT,
    type TEXT,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    version TEXT,
    content JSONB,
    applicable_roles TEXT[]
);

CREATE TRIGGER handle_updated_at_processes
BEFORE UPDATE ON processes
FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_processes_status ON processes(status);

COMMIT;