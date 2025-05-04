-- Headquarters table definition
CREATE TABLE headquarters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(35) NOT NULL,
    country_id UUID REFERENCES countries(id) ON DELETE RESTRICT,
    address TEXT,
    contact_info JSONB DEFAULT '{}',
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active', -- SUGGESTION: Consider ENUM for status for type safety.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_headquarters
    BEFORE UPDATE ON headquarters
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_headquarters_country_id ON headquarters(country_id); -- Support country-based queries

-- Enable Row Level Security
ALTER TABLE headquarters ENABLE ROW LEVEL SECURITY;

-- Policies for the headquarters table

-- SELECT: Allow any authenticated user to view headquarters
CREATE POLICY hq_select_auth
ON headquarters FOR SELECT
TO authenticated
USING (true OR fn_is_general_director_or_higher());

-- INSERT: Allow only general directors or higher
CREATE POLICY hq_insert_high_level
ON headquarters FOR INSERT
TO authenticated
WITH CHECK ( fn_is_general_director_or_higher() );

-- UPDATE: Allow only general directors or higher
CREATE POLICY hq_update_high_level
ON headquarters FOR UPDATE
TO authenticated
USING ( fn_is_general_director_or_higher() )
WITH CHECK ( fn_is_general_director_or_higher() );

-- DELETE: Allow only general directors or higher
CREATE POLICY hq_delete_high_level
ON headquarters FOR DELETE
TO authenticated
USING ( fn_is_general_director_or_higher() );
