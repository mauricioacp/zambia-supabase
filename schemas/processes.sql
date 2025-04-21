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
