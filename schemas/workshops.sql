-- Workshops table definition
CREATE TABLE workshops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    facilitator_user_id UUID REFERENCES collaborators(user_id) ON DELETE SET NULL,
    capacity INTEGER,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_workshops
    BEFORE UPDATE ON workshops
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_workshops_headquarter_id ON workshops(headquarter_id);
CREATE INDEX idx_workshops_season_id ON workshops(season_id);
CREATE INDEX idx_workshops_facilitator_user_id ON workshops(facilitator_user_id);
CREATE INDEX idx_workshops_status ON workshops(status);

-- Enable Row Level Security
ALTER TABLE workshops ENABLE ROW LEVEL SECURITY;

-- Policies for the workshops table

-- SELECT: Authenticated users in their HQ, or high level (>=80) anywhere
CREATE POLICY workshops_select_auth_hq
ON workshops FOR SELECT
USING (
    (auth.role() = 'authenticated' AND headquarter_id = fn_get_current_hq_id()) OR
    fn_get_current_role_level() >= 80 OR
    facilitator_user_id = (select auth.uid())
);

-- INSERT: Manager+ (>=50) for own HQ, Director+ (>=90) for any HQ
CREATE POLICY workshops_insert_manager_director
ON workshops FOR INSERT
WITH CHECK (
    (fn_get_current_role_level() >= 50 AND headquarter_id = fn_get_current_hq_id()) OR
    fn_get_current_role_level() >= 90
);

-- UPDATE: Assigned facilitator, manager+ (>=50) for own HQ, director+ (>=90) for any
CREATE POLICY workshops_update_facilitator_manager_director
ON workshops FOR UPDATE
USING (
    -- User is the assigned facilitator (assuming facilitator_user_id = auth.uid())
    facilitator_user_id = (select auth.uid()) OR
    -- User is Manager+ for the workshop's current HQ
    (fn_get_current_role_level() >= 50 AND headquarter_id = fn_get_current_hq_id()) OR
    -- User is Director+
    fn_get_current_role_level() >= 90
)
WITH CHECK (
    -- The resulting workshop's HQ must match the user's current HQ,
    -- UNLESS the user is a Director+ who can place it anywhere.
    (headquarter_id = fn_get_current_hq_id()) OR
    (fn_get_current_role_level() >= 90)
);

-- DELETE: Director+ (>=90) only
CREATE POLICY workshops_delete_director
ON workshops FOR DELETE
USING ( fn_get_current_role_level() >= 90 );
