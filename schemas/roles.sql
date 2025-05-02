-- Roles table definition
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active', -- SUGGESTION: Consider ENUM for status for type safety.
    level INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    permissions JSONB DEFAULT '{}'
);

CREATE TRIGGER handle_updated_at_roles
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_roles_code ON roles(code); -- Support fast lookup by code

-- Enable Row Level Security
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

-- Policies for the role table

-- SELECT: Allow any authenticated user to view roles
CREATE POLICY roles_select_auth
ON roles FOR SELECT
TO authenticated
USING (true);

-- INSERT, UPDATE, DELETE: Allow only superadmin roles (>=100)
CREATE POLICY roles_manage_superadmin
ON roles FOR ALL -- Applies to INSERT, UPDATE, DELETE
USING ( fn_get_current_role_level() >= 100 )
WITH CHECK ( fn_get_current_role_level() >= 100 );

CREATE OR REPLACE FUNCTION fn_is_role_level_below(p_role_id UUID, p_level_threshold INT)
    RETURNS BOOLEAN AS $$
    DECLARE
role_level INT;
BEGIN
SELECT level INTO role_level FROM roles WHERE id = p_role_id;
RETURN role_level < p_level_threshold;
END;
    $$ LANGUAGE plpgsql STABLE;
