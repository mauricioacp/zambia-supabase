CREATE TYPE collaborator_status AS ENUM ('active', 'inactive', 'standby');

-- Collaborators table definition
CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE RESTRICT ,
    headquarter_id UUID NOT NULL REFERENCES headquarters(id) ON DELETE RESTRICT,
    status collaborator_status DEFAULT 'inactive',
    start_date DATE,
    end_date DATE
);

CREATE INDEX idx_collaborators_user_id ON collaborators(user_id);
CREATE INDEX idx_collaborators_role_id ON collaborators(role_id);
CREATE INDEX idx_collaborators_headquarter_id ON collaborators(headquarter_id);

ALTER TABLE collaborators ENABLE ROW LEVEL SECURITY;

-- trigger to ensure collaborator has a valid agreement
CREATE OR REPLACE FUNCTION check_collaborator_has_agreement()
    RETURNS TRIGGER 
    SET search_path = ''
    AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.agreements WHERE user_id = NEW.user_id) THEN
        RAISE EXCEPTION 'Collaborator must have a valid agreement';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Policies for the collaborators table

-- SELECT: Own record, same HQ if level >= 50, any if level >= 90
CREATE POLICY collaborators_select_self_hq_high
ON collaborators FOR SELECT
USING (
    user_id = (select auth.uid()) OR
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR
    fn_is_general_director_or_higher()
);

-- INSERT: Manager+ for own HQ, Director+ for any HQ/role
CREATE POLICY collaborators_insert_manager_director
ON collaborators FOR INSERT
WITH CHECK (
    (
        fn_is_local_manager_or_higher()
        AND fn_is_current_user_hq_equal_to(headquarter_id)
    )
    OR fn_is_general_director_or_higher()
);

-- UPDATE: Own record, manager+ for own HQ (only roles <95), director+ for any
CREATE POLICY collaborators_update_self_manager_director
ON collaborators FOR UPDATE
USING (
    user_id = (select auth.uid()) OR
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR
    fn_is_general_director_or_higher()
)
WITH CHECK (
    user_id = (select auth.uid())
    OR (
        fn_is_local_manager_or_higher()
        AND fn_is_current_user_hq_equal_to(headquarter_id)
        AND (SELECT level FROM roles WHERE id = role_id) < 95
        )
    OR fn_is_general_director_or_higher()
);

-- DELETE: Director+ only
CREATE POLICY general_director_can_delete_collaborators
ON collaborators FOR DELETE
USING ( fn_is_general_director_or_higher() );
