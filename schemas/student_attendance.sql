-- schemas/student_attendance.sql

CREATE TABLE student_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scheduled_workshop_id UUID NOT NULL REFERENCES scheduled_workshops(id) ON DELETE CASCADE, -- Cascade delete if workshop instance deleted
    student_id UUID NOT NULL REFERENCES students(user_id) ON DELETE CASCADE, -- Cascade delete if student deleted
    attendance_status TEXT NOT NULL CHECK (attendance_status IN ('present', 'absent')),
    attendance_timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL, -- When the record was created/marked
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ,
    -- A student can only have one attendance status record per workshop instance
    CONSTRAINT uq_student_workshop_attendance UNIQUE (scheduled_workshop_id, student_id)
);

COMMENT ON TABLE student_attendance IS 'Tracks student attendance for specific scheduled workshop instances.';
COMMENT ON COLUMN student_attendance.scheduled_workshop_id IS 'The specific workshop instance attended.';
COMMENT ON COLUMN student_attendance.student_id IS 'The student whose attendance is being tracked.';
COMMENT ON COLUMN student_attendance.attendance_status IS 'Attendance status (present, absent, excused).';
COMMENT ON COLUMN student_attendance.attendance_timestamp IS 'Timestamp when attendance was recorded.';

CREATE INDEX idx_student_attendance_workshop ON student_attendance(scheduled_workshop_id);
CREATE INDEX idx_student_attendance_student ON student_attendance(student_id);

CREATE TRIGGER handle_updated_at_student_attendance
    BEFORE UPDATE ON student_attendance
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- Enable Row Level Security
ALTER TABLE student_attendance ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Example - Adjust as needed)
-- SELECT: Student sees own, Facilitator sees own workshop's, Manager Assistant+ sees own HQ's, Director+ sees all
CREATE POLICY student_attendance_select_policy
    ON student_attendance FOR SELECT
    TO authenticated
    USING (
        student_id =(select auth.uid()) -- Student sees their own records
        OR
        -- Facilitator sees attendance for scheduled_workshops they facilitate
        EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.facilitator_id = (select auth.uid())
        )
        OR
        -- Manager Assistant+ sees attendance for scheduled_workshops in their HQ
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        fn_is_general_director_or_higher() -- Director+ sees all
    );

-- INSERT: Facilitator for own workshop, Manager Assistant+ for own HQ, Director+ for any
CREATE POLICY student_attendance_insert_policy
    ON student_attendance FOR INSERT
    TO authenticated
    WITH CHECK (
        -- Facilitator managing attendance for scheduled_workshops they facilitate
        EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.facilitator_id = (select auth.uid())
        )
        OR
        -- Manager Assistant+ managing attendance for scheduled_workshops in their HQ
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        fn_is_general_director_or_higher() -- Director+ managing all
    );

-- UPDATE: Facilitator for own workshop, Manager Assistant+ for own HQ, Director+ for any
CREATE POLICY student_attendance_update_policy
    ON student_attendance FOR UPDATE
    TO authenticated
    USING (
        -- Facilitator managing attendance for scheduled_workshops they facilitate
        EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.facilitator_id = (select auth.uid())
        )
        OR
        -- Manager Assistant+ managing attendance for scheduled_workshops in their HQ
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        fn_is_general_director_or_higher() -- Director+ managing all
    )
    WITH CHECK (
        -- Same check logic as USING for simplicity here
        EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.facilitator_id = (select auth.uid())
        )
        OR
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        fn_is_general_director_or_higher()
    );

-- DELETE: Facilitator for own workshop, Manager Assistant+ for own HQ, Director+ for any
CREATE POLICY student_attendance_delete_policy
    ON student_attendance FOR DELETE
    TO authenticated
    USING (
        -- Facilitator managing attendance for scheduled_workshops they facilitate
        EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.facilitator_id = (select auth.uid())
        )
        OR
        -- Manager Assistant+ managing attendance for scheduled_workshops in their HQ
        (fn_is_manager_assistant_or_higher() AND EXISTS (
            SELECT 1 FROM scheduled_workshops sw
            WHERE sw.id = student_attendance.scheduled_workshop_id AND sw.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        fn_is_general_director_or_higher() -- Director+ managing all
    );
