-- Agreements table definition
CREATE TABLE agreements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL NULL, -- Allow NULL for development
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
    status TEXT CHECK (status IN ('active', 'graduated', 'inactive', 'prospect')) DEFAULT 'prospect',
    email TEXT NOT NULL,
    document_number TEXT,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    name TEXT,
    last_name TEXT,
    address TEXT,
    volunteering_agreement BOOLEAN DEFAULT FALSE,
    ethical_document_agreement BOOLEAN DEFAULT FALSE,
    mailing_agreement BOOLEAN DEFAULT FALSE,
    age_verification BOOLEAN DEFAULT FALSE,
    signature_data TEXT,
    UNIQUE (user_id, season_id)
);

CREATE TRIGGER handle_updated_at_agreements
    BEFORE UPDATE ON agreements
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_agreements_user_id ON agreements(user_id);
CREATE INDEX idx_agreements_headquarter_id ON agreements(headquarter_id);
CREATE INDEX idx_agreements_season_id ON agreements(season_id);
CREATE INDEX idx_agreements_email ON agreements(email);
CREATE INDEX idx_agreements_document_number ON agreements(document_number);
CREATE INDEX idx_agreements_phone ON agreements(phone);
CREATE INDEX idx_agreements_name ON agreements(name);
CREATE INDEX idx_agreements_last_name ON agreements(last_name);

-- Enable Row Level Security
ALTER TABLE agreements ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view agreements"
ON agreements
FOR SELECT
TO authenticated
USING (true);

-- INSERT policy
CREATE POLICY "Allow authenticated users to insert agreements"
ON agreements
FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE policy
CREATE POLICY "Allow authenticated users to update agreements"
ON agreements
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- DELETE policy
CREATE POLICY "Allow authenticated users to delete agreements"
ON agreements
FOR DELETE
TO authenticated
USING (true);