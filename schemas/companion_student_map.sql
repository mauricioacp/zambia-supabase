-- schemas/companion_student_map.sql

CREATE TABLE companion_student_map (
    companion_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES students(user_id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    CONSTRAINT companion_student_map_pkey PRIMARY KEY (companion_id, student_id)
    -- Todo each headquarter each season generates a map
);

CREATE INDEX idx_companion_student_map_companion_id ON companion_student_map(companion_id);
CREATE INDEX idx_companion_student_map_student_id ON companion_student_map(student_id);

ALTER TABLE companion_student_map ENABLE ROW LEVEL SECURITY;

-- Combined SELECT: Collaborator+ level sees own assignments, Manager+ sees HQ assignments, Director+ sees all
CREATE POLICY "Allow SELECT for companion, managers, directors" ON companion_student_map
    FOR SELECT
    USING (
        -- Assigned Companion
        (select auth.uid()) = companion_id
        OR
        -- HQ Manager+ sees students in their HQ
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        -- Konsejo+ sees all records
        (fn_is_konsejo_member_or_higher())
    );

-- INSERT: Manager assistant+ for own HQ, Director+ for any
CREATE POLICY "Allow INSERT for HQ Managers and Directors" ON companion_student_map
    FOR INSERT
    WITH CHECK (
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM students s
            JOIN collaborators c ON c.user_id = companion_student_map.companion_id
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = fn_get_current_hq_id()
            AND c.headquarter_id = s.headquarter_id
        ))
        OR
      (fn_is_konsejo_member_or_higher())
    );

-- UPDATE: Manager assistant+ for own HQ, Director+ for any
CREATE POLICY "Allow UPDATE for HQ Managers and Directors" ON companion_student_map
    FOR UPDATE
    USING (
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_is_konsejo_member_or_higher())
    );
    -- WITH CHECK can reuse USING expression logic for UPDATE

-- DELETE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow DELETE for HQ Managers and Directors" ON companion_student_map
    FOR DELETE
    USING (
        (fn_is_local_manager_or_higher() AND EXISTS (
            SELECT 1 FROM students s
            WHERE s.user_id = companion_student_map.student_id
            AND s.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_is_konsejo_member_or_higher())
    );

-- Ensure updated_at is set
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON companion_student_map
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);
