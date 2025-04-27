-- schemas/facilitator_workshop_map.sql

CREATE TABLE facilitator_workshop_map (
    facilitator_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    workshop_id uuid NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,
    headquarter_id uuid NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT, 
    season_id uuid NOT NULL REFERENCES seasons(id) ON DELETE CASCADE, 
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    -- PRIMARY KEY
    CONSTRAINT facilitator_workshop_map_pkey PRIMARY KEY (facilitator_id, workshop_id, season_id, headquarter_id) 
);

COMMENT ON TABLE facilitator_workshop_map IS 'Maps facilitators to workshops for a specific season and headquarter.';
COMMENT ON COLUMN facilitator_workshop_map.headquarter_id IS 'The headquarter this mapping belongs to.';
COMMENT ON COLUMN facilitator_workshop_map.season_id IS 'The season this mapping belongs to.';

-- INDEXES
CREATE INDEX idx_facilitator_workshop_map_facilitator_id ON facilitator_workshop_map(facilitator_id);
CREATE INDEX idx_facilitator_workshop_map_workshop_id ON facilitator_workshop_map(workshop_id);
CREATE INDEX idx_facilitator_workshop_map_headquarter_id ON facilitator_workshop_map(headquarter_id); 
CREATE INDEX idx_facilitator_workshop_map_season_id ON facilitator_workshop_map(season_id); 

-- RLS
ALTER TABLE facilitator_workshop_map ENABLE ROW LEVEL SECURITY;

-- POLICIES
-- SELECT Policy:
-- Facilitator sees their own maps.
-- Manager Assistant+ sees all maps for their HQ (all seasons).
-- Director+ sees all maps for all HQs (all seasons).
CREATE POLICY select_facilitator_map
ON facilitator_workshop_map FOR SELECT
USING (
    auth.uid() = facilitator_id
    OR
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);

-- INSERT Policy:
-- Manager Assistant+ can insert maps for their HQ.
-- Director+ can insert maps for any HQ.
CREATE POLICY insert_facilitator_map
ON facilitator_workshop_map FOR INSERT
WITH CHECK (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);

-- UPDATE Policy:
-- Manager Assistant+ can update maps for their HQ.
-- Director+ can update maps for any HQ.
-- Prevent changing key identifiers unless Director+
CREATE POLICY update_facilitator_map
ON facilitator_workshop_map FOR UPDATE
USING (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
)
WITH CHECK (
    -- Ensure the HQ/Season isn't changed unless by Director+
    (headquarter_id = OLD.headquarter_id AND season_id = OLD.season_id)
    OR
    fn_is_general_director_or_higher()
);


-- DELETE Policy:
-- Manager Assistant+ can delete maps from their HQ.
-- Director+ can delete maps from any HQ.
CREATE POLICY delete_facilitator_map
ON facilitator_workshop_map FOR DELETE
USING (
    (fn_is_manager_assistant_or_higher() AND headquarter_id = fn_get_current_hq_id())
    OR
    fn_is_general_director_or_higher()
);

-- Ensure updated_at is set
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON facilitator_workshop_map
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);
