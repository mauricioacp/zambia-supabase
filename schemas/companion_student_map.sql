-- schemas/companion_student_map.sql

CREATE TABLE companion_student_map (
    companion_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    -- PRIMARY KEY
    CONSTRAINT companion_student_map_pkey PRIMARY KEY (companion_id, student_id)
);

-- INDEXES
CREATE INDEX idx_companion_student_map_companion_id ON companion_student_map(companion_id);
CREATE INDEX idx_companion_student_map_student_id ON companion_student_map(student_id);

-- RLS
ALTER TABLE companion_student_map ENABLE ROW LEVEL SECURITY;

-- POLICIES
-- SELECT: Companion sees own assignments, Manager+ sees HQ assignments, Director+ sees all
CREATE POLICY "Allow SELECT for assigned Companion" ON companion_student_map
    FOR SELECT
    USING (auth.uid() = companion_id);

CREATE POLICY "Allow SELECT for HQ Managers and Directors" ON companion_student_map
    FOR SELECT
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = ANY(fn_get_current_user_headquarter_ids())
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- INSERT: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow INSERT for HQ Managers and Directors" ON companion_student_map
    FOR INSERT
    WITH CHECK (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM students s
            JOIN collaborators c ON c.user_id = companion_student_map.companion_id
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = ANY(fn_get_current_user_headquarter_ids())
            AND c.headquarter_id = s.headquarter_id -- Ensure companion is also in the same HQ for manager insert
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- UPDATE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow UPDATE for HQ Managers and Directors" ON companion_student_map
    FOR UPDATE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = ANY(fn_get_current_user_headquarter_ids())
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );
    -- WITH CHECK can reuse USING expression logic for UPDATE

-- DELETE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow DELETE for HQ Managers and Directors" ON companion_student_map
    FOR DELETE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = ANY(fn_get_current_user_headquarter_ids())
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );


-- Ensure updated_at is set
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON companion_student_map
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);

