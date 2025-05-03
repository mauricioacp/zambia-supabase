-- schemas/facilitator_workshop_map.sql

CREATE TABLE facilitator_workshop_map (
    facilitator_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    workshop_id uuid NOT NULL REFERENCES scheduled_workshops(id) ON DELETE CASCADE,
    headquarter_id uuid NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT, 
    season_id uuid NOT NULL REFERENCES seasons(id) ON DELETE CASCADE, 
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    -- PRIMARY KEY
    CONSTRAINT facilitator_workshop_map_pkey PRIMARY KEY (facilitator_id, workshop_id, season_id, headquarter_id) -- PK ensures uniqueness
);

-- TRIGGER: Enforce consistency between facilitator, workshop, HQ, and season
CREATE OR REPLACE FUNCTION check_facilitator_workshop_map_consistency()
RETURNS TRIGGER 
SET search_path = ''
AS $$
DECLARE
    facilitator_hq_id UUID;
    workshop_hq_id UUID;
    workshop_season_id UUID;
BEGIN
    -- Get facilitator's HQ
    SELECT c.headquarter_id INTO facilitator_hq_id
    FROM public.collaborators c
    WHERE c.user_id = NEW.facilitator_id
    LIMIT 1;

    -- Get workshop's HQ and season
    SELECT w.headquarter_id, w.season_id INTO workshop_hq_id, workshop_season_id
    FROM public.scheduled_workshops w
    WHERE w.id = NEW.workshop_id
    LIMIT 1;

    IF NEW.headquarter_id IS DISTINCT FROM facilitator_hq_id THEN
        RAISE EXCEPTION 'Facilitator HQ (%) does not match mapping HQ (%)', facilitator_hq_id, NEW.headquarter_id;
    END IF;
    IF NEW.headquarter_id IS DISTINCT FROM workshop_hq_id THEN
        RAISE EXCEPTION 'Workshop HQ (%) does not match mapping HQ (%)', workshop_hq_id, NEW.headquarter_id;
    END IF;
    IF NEW.season_id IS DISTINCT FROM workshop_season_id THEN
        RAISE EXCEPTION 'Workshop season (%) does not match mapping season (%)', workshop_season_id, NEW.season_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

CREATE TRIGGER ensure_facilitator_workshop_map_consistency
    BEFORE INSERT OR UPDATE ON facilitator_workshop_map
    FOR EACH ROW EXECUTE FUNCTION check_facilitator_workshop_map_consistency();


COMMENT ON TABLE facilitator_workshop_map IS 'Maps facilitators to scheduled_workshops for a specific season and headquarter.';
COMMENT ON COLUMN facilitator_workshop_map.headquarter_id IS 'The headquarter this mapping belongs to.';
COMMENT ON COLUMN facilitator_workshop_map.season_id IS 'The season this mapping belongs to.';

-- INDEXES
CREATE INDEX idx_facilitator_workshop_map_facilitator_id ON facilitator_workshop_map(facilitator_id);
CREATE INDEX idx_facilitator_workshop_map_workshop_id ON facilitator_workshop_map(workshop_id);
CREATE INDEX idx_facilitator_workshop_map_headquarter_id ON facilitator_workshop_map(headquarter_id); 
CREATE INDEX idx_facilitator_workshop_map_season_id ON facilitator_workshop_map(season_id); 

-- COMPOSITE INDEXES
CREATE INDEX idx_facilitator_workshop_map_headquarter_season ON facilitator_workshop_map(headquarter_id, season_id);
CREATE INDEX idx_facilitator_workshop_map_facilitator_season ON facilitator_workshop_map(facilitator_id, season_id);
CREATE INDEX idx_facilitator_workshop_map_workshop_season ON facilitator_workshop_map(workshop_id, season_id);
CREATE INDEX idx_facilitator_workshop_map_headquarter_workshop ON facilitator_workshop_map(headquarter_id, workshop_id);
CREATE INDEX idx_facilitator_workshop_map_facilitator_workshop ON facilitator_workshop_map(facilitator_id, workshop_id);
CREATE INDEX idx_facilitator_workshop_map_headquarter_facilitator ON facilitator_workshop_map(headquarter_id, facilitator_id);

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
    (select auth.uid())= facilitator_id
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
    (headquarter_id = headquarter_id AND season_id = season_id)
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
