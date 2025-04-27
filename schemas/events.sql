-- Events table definition
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID REFERENCES seasons(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    data JSONB,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft',
    event_type_id integer REFERENCES event_types(id) ON DELETE RESTRICT
);

CREATE TRIGGER handle_updated_at_events
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_events_headquarter_id ON events(headquarter_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_datetime ON events(start_datetime);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policies for the events table

-- SELECT: Authenticated users in their HQ, or konsejo_member_or_higher anywhere
CREATE POLICY events_select_auth_hq
ON events FOR SELECT
TO authenticated
USING (
    headquarter_id = fn_get_current_hq_id() OR
    fn_is_konsejo_member_or_higher()
);

-- INSERT: collaborator_or_higher+ for own HQ, konsejo_member_or_higher for any HQ
-- Collaborators can create events of type 'companion-activity' for example
CREATE POLICY events_insert_collaborator_konsejo
ON events FOR INSERT
WITH CHECK (
    (fn_is_collaborator_or_higher() AND headquarter_id = fn_get_current_hq_id()) OR
    fn_is_konsejo_member_or_higher()
);

-- UPDATE: collaborator_or_higher+ for own HQ, konsejo_member_or_higher for any HQ
CREATE POLICY events_update_collaborator_konsejo
ON events FOR UPDATE
USING (
    (fn_is_collaborator_or_higher() AND headquarter_id = fn_get_current_hq_id()) OR
    fn_is_konsejo_member_or_higher()
)WITH CHECK (
    -- Can only change HQ/Season if Konsejo Member+
    (headquarter_id = OLD.headquarter_id AND season_id = OLD.season_id)
    OR
    fn_is_konsejo_member_or_higher()
);

-- DELETE: Director+ only
CREATE POLICY events_delete_director
ON events FOR DELETE
USING ( fn_is_general_director_or_higher() );
