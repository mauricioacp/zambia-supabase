-- Seasons table definition
CREATE TABLE seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    headquarter_id UUID NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT,
    manager_id UUID NULL REFERENCES collaborators(user_id) ON DELETE SET NULL,
    start_date DATE,
    end_date DATE,
    status TEXT CHECK (status IN ('active', 'inactive', 'completed')) DEFAULT 'inactive',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_season_name_per_hq UNIQUE (name, headquarter_id),
    CONSTRAINT check_season_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

COMMENT ON TABLE seasons IS 'Defines operational seasons within a headquarter.';
COMMENT ON COLUMN seasons.headquarter_id IS 'The headquarter this season belongs to.';
COMMENT ON COLUMN seasons.manager_id IS 'Optional manager (collaborator) assigned to oversee the season.';
COMMENT ON COLUMN seasons.status IS 'Current status of the season lifecycle.';
COMMENT ON CONSTRAINT unique_season_name_per_hq ON seasons IS 'Ensures season names are unique within each headquarter.';
COMMENT ON CONSTRAINT check_season_dates ON seasons IS 'Ensures end_date is not before start_date.';


CREATE TRIGGER handle_updated_at_seasons
    BEFORE UPDATE ON seasons
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_seasons_headquarter_id ON seasons(headquarter_id);
CREATE INDEX idx_seasons_manager_id ON seasons(manager_id);
CREATE INDEX idx_seasons_status ON seasons(status); -- Added index on status
CREATE INDEX idx_seasons_start_date ON seasons(start_date); -- Added index on start_date

ALTER TABLE seasons ENABLE ROW LEVEL SECURITY;

-- Policies for the seasons table (using helper functions)

-- SELECT policy: View own HQ's seasons or all if Konsejo Member+
CREATE POLICY seasons_select_policy
ON seasons FOR SELECT
TO authenticated
USING (
    headquarter_id = fn_get_current_hq_id()
    OR
    fn_is_konsejo_member_or_higher() -- Konsejo+ can see all
);

-- INSERT policy: Konsejo+ for own HQ, General Director+ for any
CREATE POLICY seasons_insert_policy
ON seasons FOR INSERT
TO authenticated
WITH CHECK (
    (fn_is_konsejo_member_or_higher() AND headquarter_id = fn_get_current_hq_id()) -- Konsejo+ can insert for own HQ
    OR
    fn_is_general_director_or_higher() -- General Director+ can insert for any HQ
);

-- UPDATE policy: Konsejo+ for own HQ (no HQ change), General Director+ for any (can change HQ)
CREATE POLICY seasons_update_policy
ON seasons FOR UPDATE
TO authenticated
USING (
    -- Target rows: Konsejo+ own HQ, or General Director+ any
    (fn_is_konsejo_member_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
)
WITH CHECK (
    -- Check after update: HQ cannot be changed unless user is General Director+
    (NEW.headquarter_id = OLD.headquarter_id AND fn_is_konsejo_member_or_higher()) -- Konsejo+ can update if HQ doesn't change
    OR
    fn_is_general_director_or_higher() -- General Director+ can update and change HQ
);

-- DELETE policy: General Director+ only
CREATE POLICY seasons_delete_policy
ON seasons FOR DELETE
TO authenticated
USING (
    fn_is_general_director_or_higher() -- Only General Director+ can delete
);