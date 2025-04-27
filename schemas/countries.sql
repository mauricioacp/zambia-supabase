-- Countries table definition
CREATE TABLE countries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    status TEXT CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_countries
    BEFORE UPDATE ON countries
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_countries_code ON countries(code);

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to view countries"
ON countries
FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow super admin to insert countries"
ON countries
FOR INSERT
TO authenticated
WITH CHECK ( fn_is_super_admin() );

CREATE POLICY "Allow super admin to update countries"
ON countries
FOR UPDATE
TO authenticated
USING ( fn_is_super_admin() )
WITH CHECK ( fn_is_super_admin() );

CREATE POLICY "Allow super admin to delete countries"
ON countries
FOR DELETE
TO authenticated
USING ( fn_is_super_admin() );
