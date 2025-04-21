-- Students table definition
CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NULL, -- Allow NULL for development
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
