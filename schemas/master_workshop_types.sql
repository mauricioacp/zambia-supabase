-- schemas/master_workshop_types.sql

CREATE TABLE master_workshop_types (
    id SERIAL PRIMARY KEY, -- Simple integer ID for the master type
    master_name TEXT NOT NULL UNIQUE, -- Official name from General Direction
    master_description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

COMMENT ON TABLE master_workshop_types IS 'Central catalog of standardized workshop types offered by the General Direction.';
COMMENT ON COLUMN master_workshop_types.master_name IS 'The official, unique name of the workshop template.';
COMMENT ON COLUMN master_workshop_types.master_description IS 'Detailed description of the master workshop template.';

CREATE TRIGGER handle_updated_at_master_workshop_types
    BEFORE UPDATE ON master_workshop_types
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);
-- SUGGESTION: If status or similar field is added, consider ENUM for type safety.

-- Enable Row Level Security
ALTER TABLE master_workshop_types ENABLE ROW LEVEL SECURITY;

-- Policies: Allow viewing by authenticated, management by high roles (e.g., Super Admin)
CREATE POLICY master_workshop_types_select_auth
    ON master_workshop_types FOR SELECT
    TO authenticated USING (true);

CREATE POLICY master_workshop_types_manage_superadmin
    ON master_workshop_types FOR ALL -- INSERT, UPDATE, DELETE
    TO authenticated
    USING ( fn_is_super_admin() ) -- Only Super Admins can manage master types
    WITH CHECK ( fn_is_super_admin() );
