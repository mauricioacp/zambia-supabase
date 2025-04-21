-- Headquarters table definition
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
