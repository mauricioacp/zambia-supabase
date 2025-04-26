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

-- Enable Row Level Security
ALTER TABLE headquarters ENABLE ROW LEVEL SECURITY;

-- Policies for the headquarters table

-- SELECT: Allow any authenticated user to view headquarters
CREATE POLICY hq_select_auth
ON headquarters FOR SELECT
TO authenticated
USING (true);

-- INSERT, UPDATE, DELETE: Allow only high-level roles (>=90)
CREATE POLICY hq_manage_high_level
ON headquarters FOR ALL -- Applies to INSERT, UPDATE, DELETE
USING ( fn_get_current_role_level() >= 90 )
WITH CHECK ( fn_get_current_role_level() >= 90 );
