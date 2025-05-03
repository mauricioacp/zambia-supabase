-- Agreements table definition
CREATE TABLE agreements
(
    id                         UUID PRIMARY KEY                                                       DEFAULT uuid_generate_v4(),
    user_id                    UUID REFERENCES auth.users (id) ON DELETE RESTRICT,
    headquarter_id             UUID REFERENCES headquarters (id) ON DELETE RESTRICT NOT NULL,
    season_id                  UUID REFERENCES seasons (id)                         NOT NULL,
    role_id                    UUID                                                 NOT NULL REFERENCES roles (id) ON DELETE RESTRICT,
    status                     TEXT CHECK (status IN ('active', 'graduated', 'inactive', 'prospect')) DEFAULT 'prospect',
    email                      TEXT                                                 NOT NULL,
    document_number            TEXT,
    phone                      TEXT,
    created_at                 TIMESTAMPTZ                                                            DEFAULT NOW(),
    updated_at                 TIMESTAMPTZ                                                            DEFAULT NOW(),
    name                       TEXT,
    last_name                  TEXT,
    address                    TEXT,
    activation_date            TIMESTAMPTZ,
    volunteering_agreement     BOOLEAN                                                                DEFAULT FALSE,
    ethical_document_agreement BOOLEAN                                                                DEFAULT FALSE,
    mailing_agreement          BOOLEAN                                                                DEFAULT FALSE,
    age_verification           BOOLEAN                                                                DEFAULT FALSE,
    signature_data             TEXT,
    birth_date                 DATE,
    gender                     TEXT CHECK (gender IN ('male', 'female', 'other', 'unknown'))          DEFAULT 'unknown',
    fts_name_lastname          tsvector,
    UNIQUE (user_id, season_id)
);

COMMENT ON TABLE agreements IS 'Table containing user agreements for seasons';
COMMENT ON COLUMN agreements.user_id IS 'User ID of the user';
COMMENT ON COLUMN agreements.headquarter_id IS 'Headquarter ID of the headquarter';
COMMENT ON COLUMN agreements.season_id IS 'Season ID of the season';
COMMENT ON COLUMN agreements.role_id IS 'Role ID of the role';
COMMENT ON COLUMN agreements.status IS 'Status of the agreement';
COMMENT ON COLUMN agreements.email IS 'Email of the user';
COMMENT ON COLUMN agreements.document_number IS 'Document number of the user';
COMMENT ON COLUMN agreements.phone IS 'Phone of the user';
COMMENT ON COLUMN agreements.created_at IS 'When the record was created';
COMMENT ON COLUMN agreements.updated_at IS 'When the record was last updated';
COMMENT ON COLUMN agreements.name IS 'Name of the user';
COMMENT ON COLUMN agreements.last_name IS 'Last name of the user';
COMMENT ON COLUMN agreements.address IS 'Address of the user';
COMMENT ON COLUMN agreements.activation_date IS 'Activation date of the user when the responsible approves from prospect to active';
COMMENT ON COLUMN agreements.volunteering_agreement IS 'Volunteering agreement of the user';
COMMENT ON COLUMN agreements.ethical_document_agreement IS 'Ethical document agreement of the user';
COMMENT ON COLUMN agreements.mailing_agreement IS 'Mailing agreement of the user';
COMMENT ON COLUMN agreements.age_verification IS 'Age verification of the user';
COMMENT ON COLUMN agreements.signature_data IS 'Signature data of the user';
COMMENT ON COLUMN agreements.birth_date IS 'Birth date of the user';
COMMENT ON COLUMN agreements.gender IS 'Gender of the user, male, other, female, unknown';
COMMENT ON COLUMN agreements.fts_name_lastname IS 'Full-text search vector for name and last name';


CREATE OR REPLACE FUNCTION set_activation_date_on_update()
    RETURNS TRIGGER AS
$$
BEGIN
    IF OLD.status = 'prospect' AND NEW.status = 'active' AND NEW.activation_date IS NULL THEN
        NEW.activation_date := NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION update_fts_name_lastname()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.fts_name_lastname :=
            to_tsvector('simple', coalesce(NEW.name, '') || ' ' || coalesce(NEW.last_name, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER handle_updated_at_agreements
    BEFORE UPDATE
    ON agreements
    FOR EACH ROW
EXECUTE PROCEDURE moddatetime(updated_at);

CREATE TRIGGER handle_activation_date
    BEFORE UPDATE
    ON agreements
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION set_activation_date_on_update();

CREATE TRIGGER handle_fts_name_lastname_update
    BEFORE INSERT OR UPDATE OF name, last_name
    ON agreements
    FOR EACH ROW
EXECUTE FUNCTION update_fts_name_lastname();

CREATE INDEX idx_agreements_user_id ON agreements (user_id);
CREATE INDEX idx_agreements_headquarter_id ON agreements (headquarter_id);
CREATE INDEX idx_agreements_season_id ON agreements (season_id);
CREATE INDEX idx_agreements_role_id ON agreements (role_id);
CREATE INDEX idx_agreements_email ON agreements (email);
CREATE INDEX idx_agreements_document_number ON agreements (document_number);
CREATE INDEX idx_agreements_phone ON agreements (phone);
CREATE INDEX idx_agreements_name ON agreements (name);
CREATE INDEX idx_agreements_last_name ON agreements (last_name);
CREATE INDEX idx_agreements_fts_name_lastname ON agreements USING gin (fts_name_lastname);

ALTER TABLE agreements
    ENABLE ROW LEVEL SECURITY;

-- SELECT: Own record, general director+ or local manager+ in same HQ
CREATE POLICY agreements_select_own_hq_high
    ON agreements FOR SELECT
    USING (
    user_id = (select auth.uid()) OR -- Own record
    fn_is_general_director_or_higher() OR
    (fn_is_local_manager_or_higher() AND
     fn_is_current_user_hq_equal_to(headquarter_id)) -- Manager + in same HQ
    );

-- INSERT (anon): Allow anonymous and authenticated users to create prospects
CREATE POLICY agreements_insert_anon_prospect
    ON agreements FOR INSERT
    TO anon, authenticated
    WITH CHECK (status = 'prospect');


-- Drop the existing policy before creating the updated one
DROP POLICY IF EXISTS agreements_update_permissions ON agreements;

-- Consolidated policy for updating agreements based on user-role and target record
CREATE POLICY agreements_update_permissions ON agreements FOR UPDATE
    USING (
    -- Determine which rows an updater can potentially target:
    -- 1. Users can target their own record for update
    user_id =(select auth.uid()) OR
        -- 2. General Directors+ can target any record
    fn_is_general_director_or_higher() OR
        -- 3. Local Managers+ can target records within their own headquarter
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id))
    )
    WITH CHECK (
    -- Define the conditions the NEW row must satisfy based on the updater's role.

    -- Universal Restrictions: Regardless of who is updating, these fields cannot be changed.
    user_id = user_id AND
    headquarter_id = headquarter_id AND
    email = email AND -- Email cannot be changed via this table's update

    -- Role-Specific Restrictions:
    (
        -- CASE 1: General Director+ is updating
        -- They are subject only to the universal restrictions above.
        fn_is_general_director_or_higher()
        )
        OR
    (
        -- CASE 2: User is updating their own record (and is NOT GD+)
        user_id =(select auth.uid()) AND
        NOT fn_is_general_director_or_higher() AND
            -- Must also not change their own role_id (in addition to universal restrictions)
        role_id = role_id
        -- Can update other fields like status, phone, address, agreements, signature, etc.
        )
        OR
    (
        -- CASE 3: Local Manager+ is updating someone else in their HQ (and is NOT GD+).
        -- Check current user is LM+ (not GD+) and is NOT the owner.
        user_id <>(select auth.uid()) AND
        fn_is_local_manager_or_higher() AND
        NOT fn_is_general_director_or_higher() AND
            -- Additional restriction: cannot assign roles with level 95 or higher.
        NOT EXISTS (SELECT 1
                    FROM public.roles -- Using EXISTS for clarity and performance
                    WHERE id = role_id
                      AND level >= 95)
        )
    );

-- Update the comment to reflect the applied restrictions
COMMENT ON POLICY agreements_update_permissions ON agreements IS
    'Defines update permissions for the agreements table:
    Universal Restrictions: user_id, headquarter_id, and email cannot be changed by any user via this policy.
    Role-Specific Logic:
    1. General Directors (or higher roles) can update any record, subject only to universal restrictions.
    2. Regular users (non-GD+) can update their own agreement, but cannot change their user_id, role_id, headquarter_id, or email.
    3. Local Managers (or higher, but non-GD+) can update records in their HQ (excluding themselves). They cannot change user_id, headquarter_id, or email, and cannot assign roles with level >= 95.';

-- DELETE: General Director+ only
CREATE POLICY agreements_delete_admin
    ON agreements FOR DELETE
    USING (fn_is_general_director_or_higher());
