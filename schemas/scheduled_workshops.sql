-- schemas/scheduled_workshops.sql

CREATE TABLE scheduled_workshops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    master_workshop_type_id INTEGER NOT NULL REFERENCES master_workshop_types(id) ON DELETE RESTRICT,
    headquarter_id UUID NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT,
    season_id UUID NOT NULL REFERENCES seasons(id) ON DELETE RESTRICT,
    -- Facilitator must be a collaborator from the *same headquarter* (enforced by trigger)
    facilitator_id UUID NOT NULL REFERENCES collaborators(user_id) ON DELETE RESTRICT,
    local_name TEXT NOT NULL, -- HQ-specific name for this instance
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ NOT NULL,
    location_details TEXT, -- E-g online, at headquarters, outside...
    status TEXT NOT NULL CHECK (status IN ('scheduled', 'completed', 'cancelled')) DEFAULT 'scheduled',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ,
    -- Ensure a specific HQ doesn't schedule the exact same local name twice in one season
    CONSTRAINT uq_local_name_hq_season UNIQUE (local_name, headquarter_id, season_id),
    -- Ensure end time is after start time
    CONSTRAINT chk_workshop_times CHECK (end_datetime > start_datetime)
);

COMMENT ON TABLE scheduled_workshops IS 'Specific instances of workshops scheduled by a headquarter for a given season.';
COMMENT ON COLUMN scheduled_workshops.master_workshop_type_id IS 'Link to the master template for this workshop.';
COMMENT ON COLUMN scheduled_workshops.headquarter_id IS 'The HQ that scheduled and is hosting this workshop instance.';
COMMENT ON COLUMN scheduled_workshops.season_id IS 'The season during which this workshop instance takes place.';
COMMENT ON COLUMN scheduled_workshops.facilitator_id IS 'The primary collaborator assigned to facilitate this specific instance.';
COMMENT ON COLUMN scheduled_workshops.local_name IS 'The name given to this workshop instance by the hosting headquarter.';
COMMENT ON COLUMN scheduled_workshops.start_datetime IS 'Start date and time of the workshop instance.';
COMMENT ON COLUMN scheduled_workshops.end_datetime IS 'End date and time of the workshop instance.';
COMMENT ON COLUMN scheduled_workshops.status IS 'The current status of the scheduled workshop instance.';

CREATE INDEX idx_scheduled_workshops_master_type ON scheduled_workshops(master_workshop_type_id);
CREATE INDEX idx_scheduled_workshops_hq ON scheduled_workshops(headquarter_id);
CREATE INDEX idx_scheduled_workshops_season ON scheduled_workshops(season_id);
CREATE INDEX idx_scheduled_workshops_facilitator ON scheduled_workshops(facilitator_id);
CREATE INDEX idx_scheduled_workshops_start_time ON scheduled_workshops(start_datetime);

CREATE TRIGGER handle_updated_at_scheduled_workshops
    BEFORE UPDATE ON scheduled_workshops
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

-- Enable Row Level Security
ALTER TABLE scheduled_workshops ENABLE ROW LEVEL SECURITY;

-- RLS Policies (Example - Adjust roles/levels as needed)
-- SELECT: Facilitator sees own, Manager Assistant+ sees own HQ, Director+ sees all
CREATE POLICY scheduled_workshops_select_policy
    ON scheduled_workshops FOR SELECT
    TO authenticated
    USING (
        facilitator_id = auth.uid()
        OR
        (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
        OR
        fn_is_general_director_or_higher()
    );

-- INSERT: Manager Assistant+ for own HQ, Director+ for any
CREATE POLICY scheduled_workshops_insert_policy
    ON scheduled_workshops FOR INSERT
    TO authenticated
    WITH CHECK (
        (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
        OR
        fn_is_general_director_or_higher()
        -- Trigger will validate facilitator role/HQ
    );

-- UPDATE: Manager Assistant+ for own HQ (no HQ/Season change), Director+ for any (can change HQ/Season)
CREATE POLICY scheduled_workshops_update_policy
    ON scheduled_workshops FOR UPDATE
    TO authenticated
    USING (
        (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
        OR
        fn_is_general_director_or_higher()
    )
    WITH CHECK (
        (headquarter_id = OLD.headquarter_id AND season_id = OLD.season_id AND fn_is_manager_assistant_or_higher())
        OR
        fn_is_general_director_or_higher()
        -- Trigger will validate facilitator role/HQ on change
    );

-- DELETE: Manager Assistant+ for own HQ, Director+ for any
CREATE POLICY scheduled_workshops_delete_policy
    ON scheduled_workshops FOR DELETE
    TO authenticated
    USING (
        (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
        OR
        fn_is_general_director_or_higher()
    );
