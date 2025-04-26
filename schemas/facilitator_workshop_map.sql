-- schemas/facilitator_workshop_map.sql

CREATE TABLE facilitator_workshop_map (
    facilitator_id uuid NOT NULL REFERENCES collaborators(user_id) ON DELETE CASCADE,
    workshop_id uuid NOT NULL REFERENCES workshops(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz,
    -- PRIMARY KEY
    CONSTRAINT facilitator_workshop_map_pkey PRIMARY KEY (facilitator_id, workshop_id)
);

-- INDEXES
CREATE INDEX idx_facilitator_workshop_map_facilitator_id ON facilitator_workshop_map(facilitator_id);
CREATE INDEX idx_facilitator_workshop_map_workshop_id ON facilitator_workshop_map(workshop_id);

-- RLS
ALTER TABLE facilitator_workshop_map ENABLE ROW LEVEL SECURITY;

-- POLICIES
-- Combined SELECT: Facilitator sees own assignments, Manager+ sees HQ assignments, Director+ sees all
CREATE POLICY "Allow SELECT for facilitator, managers, directors" ON facilitator_workshop_map
    FOR SELECT
    USING (
        -- Assigned Facilitator
        (select auth.uid()) = facilitator_id
        OR
        -- HQ Manager+ (level 50+) sees workshops in their HQ
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM workshops w
            WHERE w.id = facilitator_workshop_map.workshop_id
            AND w.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        -- Director+ (level 80+) sees all
        (fn_get_current_role_level() >= 80)
    );

-- INSERT: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow INSERT for HQ Managers and Directors" ON facilitator_workshop_map
    FOR INSERT
    WITH CHECK (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM workshops w
            JOIN collaborators c ON c.user_id = facilitator_workshop_map.facilitator_id
            WHERE w.id = facilitator_workshop_map.workshop_id
            AND w.headquarter_id = fn_get_current_hq_id()
            AND c.headquarter_id = w.headquarter_id -- Ensure facilitator and workshop are in the same HQ for manager insert
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- UPDATE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow UPDATE for HQ Managers and Directors" ON facilitator_workshop_map
    FOR UPDATE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM workshops w
            WHERE w.id = facilitator_workshop_map.workshop_id
            AND w.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );
    -- WITH CHECK can reuse USING expression logic for UPDATE

-- DELETE: Manager+ for own HQ, Director+ for any
CREATE POLICY "Allow DELETE for HQ Managers and Directors" ON facilitator_workshop_map
    FOR DELETE
    USING (
        (fn_get_current_role_level() >= 50 AND EXISTS (
            SELECT 1 FROM workshops w
            WHERE w.id = facilitator_workshop_map.workshop_id
            AND w.headquarter_id = fn_get_current_hq_id()
        ))
        OR
        (fn_get_current_role_level() >= 80)
    );

-- Ensure updated_at is set
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON facilitator_workshop_map
  FOR EACH ROW EXECUTE PROCEDURE moddatetime (updated_at);
