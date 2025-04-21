-- Processes table definition
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

-- Enable Row Level Security
ALTER TABLE processes ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view processes"
ON processes
FOR SELECT
TO authenticated
USING (true);

-- INSERT policy
CREATE POLICY "Allow authenticated users to insert processes"
ON processes
FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE policy
CREATE POLICY "Allow authenticated users to update processes"
ON processes
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- DELETE policy
CREATE POLICY "Allow authenticated users to delete processes"
ON processes
FOR DELETE
TO authenticated
USING (true);
