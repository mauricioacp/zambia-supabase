-- Agreements table definition
CREATE TABLE agreements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Allow NULL for development
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
    activation_date TIMESTAMPTZ NULL,
    volunteering_agreement BOOLEAN DEFAULT FALSE,
    ethical_document_agreement BOOLEAN DEFAULT FALSE,
    mailing_agreement BOOLEAN DEFAULT FALSE,
    age_verification BOOLEAN DEFAULT FALSE,
    signature_data TEXT,
    UNIQUE (user_id, season_id)
);

-- Trigger function to set activation date on status change
CREATE OR REPLACE FUNCTION set_activation_date_on_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if status changed from 'prospect' to 'active' and activation_date is not already set
    IF OLD.status = 'prospect' AND NEW.status = 'active' AND NEW.activation_date IS NULL THEN
        NEW.activation_date := NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update 'updated_at'
CREATE TRIGGER handle_updated_at_agreements
    BEFORE UPDATE ON agreements
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- Trigger to set activation date
CREATE TRIGGER handle_activation_date
    BEFORE UPDATE ON agreements
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status) -- Only run if status potentially changes
    EXECUTE FUNCTION set_activation_date_on_update();

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

-- Policies for the agreements table

-- SELECT: Own record, high level role (>=80), or same HQ
CREATE POLICY agreements_select_own_hq_high
ON agreements FOR SELECT
USING (
    user_id = auth.uid() OR
    fn_get_current_role_level() >= 80 OR
    headquarter_id = fn_get_current_hq_id()
);

-- INSERT (anon): Allow anonymous users to create prospects
CREATE POLICY agreements_insert_anon_prospect
ON agreements FOR INSERT
TO anon
WITH CHECK ( status = 'prospect' );

-- INSERT (authenticated): Allow manager+ (>=50) to insert
CREATE POLICY agreements_insert_manager_auth
ON agreements FOR INSERT
TO authenticated
WITH CHECK ( fn_get_current_role_level() >= 50 );

-- UPDATE: Own record or manager+ (>=50)
CREATE POLICY agreements_update_own_manager
ON agreements FOR UPDATE
USING (
    user_id = auth.uid() OR
    fn_get_current_role_level() >= 50
)
WITH CHECK (
    fn_get_current_role_level() >= 50
);

-- DELETE: Admin only (>=100)
CREATE POLICY agreements_delete_admin
ON agreements FOR DELETE
USING ( fn_get_current_role_level() >= 100 );