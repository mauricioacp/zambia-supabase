-- Events table definition
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    location JSONB,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft',
    event_type TEXT
);

CREATE TRIGGER handle_updated_at_events
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_events_headquarter_id ON events(headquarter_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_datetime ON events(start_datetime);

-- Enable Row Level Security
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policies for the events table

-- SELECT: Authenticated users in their HQ, or high level (>=80) anywhere
CREATE POLICY events_select_auth_hq
ON events FOR SELECT
USING (
    (auth.role() = 'authenticated' AND headquarter_id = fn_get_current_hq_id()) OR
    fn_get_current_role_level() >= 80
    OR user_id = (select auth.uid())
);

-- INSERT: Manager+ (>=50) for own HQ, Director+ (>=90) for any HQ
CREATE POLICY events_insert_manager_director
ON events FOR INSERT
WITH CHECK (
    (fn_get_current_role_level() >= 50 AND headquarter_id = fn_get_current_hq_id()) OR
    fn_get_current_role_level() >= 90
);

-- UPDATE: Manager+ (>=50) for own HQ, director+ (>=90) for any
CREATE POLICY events_update_manager_director
ON events FOR UPDATE
USING (
    (fn_get_current_role_level() >= 50 AND headquarter_id = fn_get_current_hq_id()) OR
    fn_get_current_role_level() >= 90
)
WITH CHECK (
    -- Checks ensure the user maintains the necessary level/association for the record they are modifying
    ( -- Manager check (if HQ is not changing or they are director)
      fn_get_current_role_level() >= 50 AND (headquarter_id = fn_get_current_hq_id() OR fn_get_current_role_level() >= 90)
    ) OR
    ( -- Director check (can modify anything)
      fn_get_current_role_level() >= 90
    )
    -- Add specific field checks if needed
);

-- DELETE: Director+ (>=90) only
CREATE POLICY events_delete_director
ON events FOR DELETE
USING ( fn_get_current_role_level() >= 90 );
