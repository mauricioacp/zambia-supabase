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

-- Enable Row Level Security
ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view countries"
ON countries
FOR SELECT
TO authenticated
USING (true);

-- INSERT policy
CREATE POLICY "Allow authenticated users to insert countries"
ON countries
FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE policy
CREATE POLICY "Allow authenticated users to update countries"
ON countries
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- DELETE policy
CREATE POLICY "Allow authenticated users to delete countries"
ON countries
FOR DELETE
TO authenticated
USING (true);
