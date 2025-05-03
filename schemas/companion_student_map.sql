-- schemas/companion_student_map.sql

CREATE TABLE companion_student_map (
    companion_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    season_id uuid NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    headquarter_id uuid NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT, 
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    CONSTRAINT companion_student_map_pkey PRIMARY KEY (companion_id, student_id, season_id) -- PK ensures uniqueness per season
);

-- TRIGGER: Enforce HQ consistency between mapping, companion, and student for the given season
CREATE OR REPLACE FUNCTION check_companion_student_hq_consistency()
RETURNS TRIGGER 
SET search_path = ''
AS $$
DECLARE
    companion_hq_id UUID;
    student_hq_id UUID;
BEGIN
    -- Get companion's HQ for the relevant season
    SELECT a.headquarter_id INTO companion_hq_id
    FROM public.agreements a
    WHERE a.user_id = NEW.companion_id AND a.season_id = NEW.season_id
    LIMIT 1;

    -- Get student's HQ for the relevant season
    SELECT a.headquarter_id INTO student_hq_id
    FROM public.agreements a
    WHERE a.user_id = NEW.student_id AND a.season_id = NEW.season_id
    LIMIT 1;

    IF NEW.headquarter_id IS DISTINCT FROM companion_hq_id THEN
        RAISE EXCEPTION 'Companion HQ (%) does not match mapping HQ (%) for season %', companion_hq_id, NEW.headquarter_id, NEW.season_id;
    END IF;
    IF NEW.headquarter_id IS DISTINCT FROM student_hq_id THEN
        RAISE EXCEPTION 'Student HQ (%) does not match mapping HQ (%) for season %', student_hq_id, NEW.headquarter_id, NEW.season_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

CREATE TRIGGER ensure_companion_student_hq_consistency
    BEFORE INSERT OR UPDATE ON companion_student_map
    FOR EACH ROW EXECUTE FUNCTION check_companion_student_hq_consistency();



COMMENT ON TABLE companion_student_map IS 'Maps companions to students for a specific season and headquarter.';
COMMENT ON COLUMN companion_student_map.season_id IS 'The season this mapping belongs to.';
COMMENT ON COLUMN companion_student_map.headquarter_id IS 'The headquarter this mapping belongs to (should match student''s HQ).';

CREATE INDEX idx_companion_student_map_companion_id ON companion_student_map(companion_id);
CREATE INDEX idx_companion_student_map_student_id ON companion_student_map(student_id);
CREATE INDEX idx_companion_student_map_season_id ON companion_student_map(season_id);
CREATE INDEX idx_companion_student_map_headquarter_id ON companion_student_map(headquarter_id);
CREATE INDEX idx_companion_student_map_agreement_id ON companion_student_map(headquarter_id, season_id);

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
    (select auth.uid()) = companion_id
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
    (headquarter_id =headquarter_id AND season_id = season_id) -- Manager+ can only update within existing HQ/Season context
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
