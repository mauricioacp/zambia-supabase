-- Processes table definition
CREATE TABLE processes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    name TEXT NOT NULL,
    description TEXT,
    type TEXT,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active', -- SUGGESTION: Consider ENUM for status for type safety.
    version TEXT,
    content JSONB,
    required_approvals UUID[]
);

CREATE TRIGGER handle_updated_at_processes
    BEFORE UPDATE ON processes
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_processes_status ON processes(status); -- Support status filtering

-- Enable Row Level Security
ALTER TABLE processes ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view processes"
ON processes
FOR SELECT
TO authenticated
USING (true);

-- INSERT: Allow only high-level roles
CREATE POLICY processes_insert_high_level
ON processes FOR INSERT
TO authenticated
WITH CHECK ( fn_is_general_director_or_higher() );

-- UPDATE: Allow only high-level roles
CREATE POLICY processes_update_high_level
ON processes FOR UPDATE
TO authenticated
USING ( fn_is_general_director_or_higher() )
WITH CHECK ( fn_is_general_director_or_higher() );

-- DELETE: Allow only high-level roles
CREATE POLICY processes_delete_high_level
ON processes FOR DELETE
TO authenticated
USING ( fn_is_general_director_or_higher() );
