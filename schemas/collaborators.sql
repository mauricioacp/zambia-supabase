-- Collaborators table definition
CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    agreement_id UUID REFERENCES agreements(id) ON DELETE RESTRICT,
    role_id UUID REFERENCES roles(id) ON DELETE RESTRICT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE RESTRICT,
    status TEXT CHECK (status IN ('active', 'inactive', 'standby')) DEFAULT 'inactive',
    start_date DATE,
    end_date DATE
);

CREATE INDEX idx_collaborators_user_id ON collaborators(user_id);
CREATE INDEX idx_collaborators_agreement_id ON collaborators(agreement_id);
CREATE INDEX idx_collaborators_role_id ON collaborators(role_id);
CREATE INDEX idx_collaborators_headquarter_id ON collaborators(headquarter_id);

ALTER TABLE collaborators ENABLE ROW LEVEL SECURITY;

-- Policies for the collaborators table

-- SELECT: Own record, same HQ if level >= 50, any if level >= 90
CREATE POLICY collaborators_select_self_hq_high
ON collaborators FOR SELECT
USING (
    user_id = (select auth.uid()) OR
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR
    fn_is_general_director_or_higher()
);

-- INSERT: Manager+ for own HQ, Director+ for any HQ
CREATE POLICY collaborators_insert_manager_director
ON collaborators FOR INSERT
WITH CHECK (
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR
    fn_is_general_director_or_higher()
);

-- UPDATE: Own record, manager+ for own HQ, director+ for any
CREATE POLICY collaborators_update_self_manager_director
ON collaborators FOR UPDATE
USING (
    user_id = (select auth.uid()) OR
    (fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)) OR
    fn_is_general_director_or_higher()
)
WITH CHECK (
    ( -- If updating own record, no specific level check needed beyond USING clause
      user_id = (select auth.uid())
    ) OR
    ( -- If updating within own HQ (and not own record), need manager+ 
      fn_is_local_manager_or_higher() AND fn_is_current_user_hq_equal_to(headquarter_id)
    ) OR
    ( -- If updating any record (and potentially changing HQ), need director+ 
      fn_is_general_director_or_higher()
    )
);

-- DELETE: Director+ only
CREATE POLICY general_director_can_delete_collaborators
ON collaborators FOR DELETE
USING ( fn_is_general_director_or_higher() );
