-- Students table definition
CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID REFERENCES seasons(id) ON DELETE RESTRICT,
    enrollment_date DATE,
    status TEXT CHECK (status IN ('active', 'prospect', 'graduated', 'inactive')) DEFAULT 'prospect',
    program_progress_comments JSONB
);

CREATE INDEX idx_students_user_id ON students(user_id);
CREATE INDEX idx_students_agreement_id ON students(agreement_id);
CREATE INDEX idx_students_headquarter_id ON students(headquarter_id);
CREATE INDEX idx_students_season_id ON students(season_id);

-- Enable Row Level Security
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Policies for the students table

-- SELECT: Own record, high level (>=80), same HQ, or assigned mentor/facilitator
CREATE POLICY students_select_own_hq_high_mentor
ON students FOR SELECT
USING (
    user_id = auth.uid() OR
    fn_get_current_role_level() >= 80 OR
    headquarter_id = fn_get_current_hq_id()
    -- TODO: Add join logic for assigned mentors (e.g., companions/facilitators)
    -- Example (requires a mapping table like companion_student_map):
    -- OR id IN (SELECT student_id FROM companion_student_map WHERE companion_id = fn_get_current_collaborator_id()) -- Need fn_get_current_collaborator_id() helper
);

-- INSERT: Allow manager+ (>=40) to insert
CREATE POLICY students_insert_manager
ON students FOR INSERT
WITH CHECK ( fn_get_current_role_level() >= 40 );

-- UPDATE: Manager+ (>=40) or assigned mentor
CREATE POLICY students_update_manager_mentor
ON students FOR UPDATE
USING (
    fn_get_current_role_level() >= 40
    -- TODO: Add logic for assigned mentors
    -- Example:
    -- OR id IN (SELECT student_id FROM companion_student_map WHERE companion_id = fn_get_current_collaborator_id())
)
WITH CHECK (
    fn_get_current_role_level() >= 40
    -- Add specific field checks here if needed
);

-- DELETE: Admin only (>=100)
CREATE POLICY students_delete_admin
ON students FOR DELETE
USING ( fn_get_current_role_level() >= 100 );
