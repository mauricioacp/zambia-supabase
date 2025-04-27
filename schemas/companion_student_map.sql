-- schemas/companion_student_map.sql

CREATE TABLE companion_student_map (
    companion_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE, -- Assuming companions are in collaborators table using user_id
    student_id uuid NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    season_id uuid NOT NULL REFERENCES seasons(id) ON DELETE CASCADE, -- Added season_id
    headquarter_id uuid NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT, -- Added headquarter_id
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    CONSTRAINT companion_student_map_pkey PRIMARY KEY (companion_id, student_id, season_id)
);

COMMENT ON TABLE companion_student_map IS 'Maps companions to students for a specific season and headquarter.';
COMMENT ON COLUMN companion_student_map.season_id IS 'The season this mapping belongs to.';
COMMENT ON COLUMN companion_student_map.headquarter_id IS 'The headquarter this mapping belongs to (should match student''s HQ).';

CREATE INDEX idx_companion_student_map_companion_id ON companion_student_map(companion_id);
CREATE INDEX idx_companion_student_map_student_id ON companion_student_map(student_id);
CREATE INDEX idx_companion_student_map_season_id ON companion_student_map(season_id);
CREATE INDEX idx_companion_student_map_headquarter_id ON companion_student_map(headquarter_id);

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON companion_student_map
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);

ALTER TABLE companion_student_map ENABLE ROW LEVEL SECURITY;

-- SELECT Policy:
-- Companion sees their own maps.
-- Manager Assistant+  sees all maps for their HQ (all seasons).
-- Director+  sees all maps for all HQs (all seasons).
CREATE POLICY select_companion_map
ON companion_student_map FOR SELECT
USING (
    auth.uid() = companion_id
    OR
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);

-- INSERT Policy:
-- Manager Assistant+ can insert maps for their HQ.
-- Director+ can insert maps for any HQ.
CREATE POLICY insert_companion_map
ON companion_student_map FOR INSERT
WITH CHECK (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);

-- UPDATE Policy:
-- Manager Assistant+ can update maps for their HQ.
-- Director+ can update maps for any HQ.
-- Prevent changing key identifiers like student_id, companion_id, season_id, headquarter_id unless Director+
CREATE POLICY update_companion_map
ON companion_student_map FOR UPDATE
USING (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
)
WITH CHECK (
    -- Ensure the HQ isn't changed unless by Director+
    (headquarter_id = OLD.headquarter_id AND season_id = OLD.season_id) -- Manager+ can only update within existing HQ/Season context
    OR
    fn_is_general_director_or_higher() -- Director+ can change anything (potentially)
);


-- DELETE Policy:
-- Manager Assistant+ can delete maps from their HQ.
-- Director+ can delete maps from any HQ.
CREATE POLICY delete_companion_map
ON companion_student_map FOR DELETE
USING (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);