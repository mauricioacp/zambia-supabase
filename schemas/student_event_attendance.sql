-- schemas/student_event_attendance.sql
-- This table is specifically for tracking attendance at mentoring events (1-to-1 sessions)
-- For workshop attendance, see student_workshop_attendance.sql

CREATE TABLE student_event_attendance (
    student_id uuid NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    attended boolean DEFAULT false NOT NULL,
    attended_at timestamptz, -- Timestamp when attendance was marked/confirmed
    notes text, -- Optional notes regarding attendance
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    -- PRIMARY KEY
    CONSTRAINT student_event_attendance_pkey PRIMARY KEY (student_id, event_id)
);

-- INDEXES
CREATE INDEX idx_student_event_attendance_student_id ON student_event_attendance(student_id);
CREATE INDEX idx_student_event_attendance_event_id ON student_event_attendance(event_id);

-- RLS
ALTER TABLE student_event_attendance ENABLE ROW LEVEL SECURITY;

-- POLICIES

-- SELECT: Student sees own attendance
CREATE POLICY "Allow SELECT for own attendance" ON student_event_attendance
    FOR SELECT
    USING ( EXISTS (
        SELECT 1 FROM students s
        WHERE s.id = student_event_attendance.student_id AND s.user_id = auth.uid()
    ));

-- SELECT: Companion sees assigned students' attendance
CREATE POLICY "Allow SELECT for Companion's assigned students" ON student_event_attendance
    FOR SELECT
    USING ( EXISTS (
        SELECT 1 FROM companion_student_map csm
        WHERE csm.companion_id = auth.uid()
        AND csm.student_id = student_event_attendance.student_id
    ));

-- SELECT: Manager+ sees HQ attendance, Director+ sees all
CREATE POLICY "Allow SELECT for HQ Managers and Directors" ON student_event_attendance
    FOR SELECT
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = student_event_attendance.event_id
            AND e.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- INSERT: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow INSERT for HQ Managers and Directors" ON student_event_attendance
    FOR INSERT
    WITH CHECK (
        (fn_get_current_role_level() >= 50 AND EXISTS (
           SELECT 1 FROM events e
           JOIN students s ON s.user_id = student_event_attendance.student_id
           WHERE e.id = student_event_attendance.event_id
           AND e.headquarter_id = fn_get_current_hq_id()
           AND s.headquarter_id = e.headquarter_id -- Student must be in same HQ as event
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- UPDATE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow UPDATE for HQ Managers and Directors" ON student_event_attendance
    FOR UPDATE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
           SELECT 1 FROM events e
           WHERE e.id = student_event_attendance.event_id
           AND e.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- DELETE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow DELETE for HQ Managers and Directors" ON student_event_attendance
    FOR DELETE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
           SELECT 1 FROM events e
           WHERE e.id = student_event_attendance.event_id
           AND e.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- Ensure updated_at is set
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON student_event_attendance
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);
