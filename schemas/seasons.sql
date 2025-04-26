-- Seasons table definition
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

-- Enable Row Level Security
ALTER TABLE seasons ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view seasons"
ON seasons
FOR SELECT
TO authenticated
USING (true);

-- INSERT, UPDATE, DELETE policy: Allow managers for own HQ, directors+ for any HQ
CREATE POLICY "Allow managers/directors to manage seasons"
ON seasons
FOR ALL -- Applies to INSERT, UPDATE, DELETE
TO authenticated
USING (
  ( fn_get_current_role_level() >= 90 ) OR
  ( fn_get_current_role_level() >= 70 AND fn_get_current_hq_id() = headquarter_id )
)
WITH CHECK (
  ( fn_get_current_role_level() >= 90 ) OR
  ( fn_get_current_role_level() >= 70 AND fn_get_current_hq_id() = headquarter_id )
);
