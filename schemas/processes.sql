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

-- INSERT, UPDATE, DELETE: Allow only high-level roles (>=90)
CREATE POLICY processes_manage_high_level
ON processes FOR ALL -- Applies to INSERT, UPDATE, DELETE
TO authenticated
USING ( fn_get_current_role_level() >= 90 )
WITH CHECK ( fn_get_current_role_level() >= 90 );
