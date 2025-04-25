
Objective: Implement a secure, consistent, and fine-grained Role-Based Access Control (RBAC) system for the Akademia Supabase project. This involves replacing existing permissive policies with specific Row-Level Security (RLS) policies, creating necessary helper functions, refining dashboard functions using SECURITY DEFINER, ensuring anonymous prospect creation, and establishing thorough testing and documentation.

Core Requirements & Constraints:

Single Role per User: Each authenticated user will have exactly one role assigned.
Metadata Storage: Crucial user context (role code, role level, role ID, associated headquarter ID, season ID, agreement ID) MUST be stored within the auth.users table's raw_user_meta_data field as a JSONB object upon user creation/update. The expected structure is:
json
CopyInsert
{
  "role": "role_code_string",
  "role_level": integer_level,
  "role_id": "role_uuid",
  "hq_id": "headquarter_uuid",
  "season_id": "season_uuid",
  "agreement_id": "agreement_uuid",
  "comments": {}
}
Anonymous Prospect Creation: The anon role MUST have permission to INSERT new records into the agreements table, but ONLY if the status column is set to 'prospect'.
No user_headquarter_map Table: This table is confirmed as unnecessary and MUST NOT be created or referenced. HQ association is derived solely from raw_user_meta_data.
SECURITY DEFINER Functions: Dashboard/analytic functions requiring data aggregation across rows potentially restricted by RLS MUST use SECURITY DEFINER. These functions MUST include internal checks to verify the calling user's role/level before executing sensitive logic.
Comprehensive Testing: Every RLS policy MUST be explicitly tested. The scripts/create-test-users.ts script needs modification to support this. Test results and corresponding documentation are required.
Consolidated Documentation: The primary documentation for implemented policies should reside in docs/supabase-rls-policies.md.
Implementation Plan (Agent Instructions):

Phase 1: Setup & Helper Functions

Verify & Standardize Metadata Population:
Task: Review the existing user creation/update mechanism (likely an Edge Function, e.g., potentially related to functions/akademy-app/routes/users.ts or seeding scripts). Ensure it consistently populates auth.users.raw_user_meta_data with the correct JSONB structure specified above for all authenticated users. Standardize this process if variations exist. // we can even extract some code to the _shared folder for all the other scripts
Rationale: Guarantees the foundation for RLS policies is reliable.
Create RBAC Helper Functions:
Task:
Create a new schema file: schemas/rbac_helpers.sql
Add schemas/rbac_helpers.sql to the schema_paths array in config.toml, placing it after extensions.sql but before table definitions.
Define the following PostgreSQL functions within this file:
sql
CopyInsert
-- Function to safely get the entire metadata object
CREATE OR REPLACE FUNCTION fn_get_current_user_metadata()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
AS $$
  SELECT COALESCE(raw_user_meta_data, '{}'::jsonb) FROM auth.users WHERE id = auth.uid();
$$;


Rationale: Provides clean, reusable, and centralized access to user metadata within RLS policies. SECURITY INVOKER is appropriate here as they just retrieve data for the calling user.
Phase 2: RLS Policy Implementation

Purge Existing Generic Policies:
Task: Go through all table schema files in schemas/ (e.g., agreements.sql, students.sql, etc.) and remove all existing CREATE POLICY statements, particularly those using USING (true).
Action: After modifying the files, run supabase db reset to apply the changes and enforce the default-deny state.
Rationale: Establishes a secure baseline before adding specific permissions.
Implement Granular RLS Policies:
Task: For each core table (agreements, students, collaborators, headquarters, workshops, events, roles, etc.), define and add specific CREATE POLICY statements directly into their respective .sql schema files. Use the helper functions created above (fn_get_current_role_level(), fn_get_current_hq_id(), etc.) extensively in USING and WITH CHECK clauses.
Reference: Base the logic on the role hierarchy defined in docs/supabase-rls-policies.md and adapt the following examples:
agreements.sql:
POLICY agreements_select_own_hq_high: FOR SELECT USING ( user_id = auth.uid() OR fn_get_current_role_level() >= 80 OR headquarter_id = fn_get_current_hq_id() )
POLICY agreements_insert_anon_prospect: FOR INSERT TO anon WITH CHECK ( status = 'prospect' )
POLICY agreements_insert_manager_auth: FOR INSERT TO authenticated WITH CHECK ( fn_get_current_role_level() >= 50 )
POLICY agreements_update_own_manager: FOR UPDATE USING ( user_id = auth.uid() OR fn_get_current_role_level() >= 50 ) WITH CHECK ( fn_get_current_role_level() >= 50 /* + specific field checks */ )
POLICY agreements_delete_admin: FOR DELETE USING ( fn_get_current_role_level() >= 100 )
Trigger: Add an ON DELETE trigger to call an audit function (ensure fn_audit_delete exists or create it).
students.sql:
POLICY students_select_own_hq_high_mentor: FOR SELECT USING ( user_id = auth.uid() OR fn_get_current_role_level() >= 80 OR headquarter_id = fn_get_current_hq_id() OR /* Add join logic for assigned mentors (companion/facilitator) */ )
POLICY students_insert_manager: FOR INSERT WITH CHECK ( fn_get_current_role_level() >= 40 )
POLICY students_update_manager_mentor: FOR UPDATE USING ( fn_get_current_role_level() >= 40 OR /* mentor logic */ ) WITH CHECK ( fn_get_current_role_level() >= 40 /* + field checks */ )
POLICY students_delete_admin: FOR DELETE USING ( fn_get_current_role_level() >= 100 )
collaborators.sql: (Define SELECT, INSERT, UPDATE, DELETE based on level, e.g., self-view/edit, manage within own HQ if level >= 50, manage any if level >= 90).
headquarters.sql:
POLICY hq_select_auth: FOR SELECT USING ( auth.role() = 'authenticated' )
POLICY hq_manage_high_level: FOR INSERT, UPDATE, DELETE USING ( fn_get_current_role_level() >= 90 ) WITH CHECK ( fn_get_current_role_level() >= 90 )
workshops.sql / events.sql: (Define policies based on role level, HQ ID, facilitator ID, participant lists).
roles.sql:
POLICY roles_select_auth: FOR SELECT USING ( auth.role() = 'authenticated' )
POLICY roles_manage_superadmin: FOR INSERT, UPDATE, DELETE USING ( fn_get_current_role_level() >= 100 ) WITH CHECK ( fn_get_current_role_level() >= 100 )
Rationale: Implements the core RBAC logic precisely according to requirements.
Phase 3: Dashboard Functions & Testing

Refine Dashboard Functions:
Task: Review and update the SQL functions get_global_dashboard_stats, get_headquarter_dashboard_stats, get_user_dashboard_stats.
Modify the RETURNS clause and function body to include all required data points specified in the documentation.
Apply SECURITY DEFINER where necessary for cross-row aggregation.
Mandatory: Add explicit checks at the beginning of each SECURITY DEFINER function body to verify the caller's authorization using fn_get_current_role_level() or fn_get_current_role_code(). Raise an exception if unauthorized. Example: IF fn_get_current_role_level() < 90 THEN RAISE EXCEPTION 'Insufficient permissions'; END IF;
Rationale: Provides required frontend data while ensuring security within the function execution context.
Implement Comprehensive Testing:
Task:
Modify scripts/create-test-users.ts to easily create test users with specific roles and correctly populated raw_user_meta_data.
For each RLS policy implemented in step 4, create specific test cases (ideally using SQL queries within a test script or framework).
Verify:
Access is granted for authorized roles/conditions.
Access is denied for unauthorized roles/conditions.
anon can insert prospect agreements.
Dashboard functions return correct data for authorized roles and block unauthorized ones.
Document these tests, linking them to the policies they cover.
Rationale: Ensures the implemented security model functions correctly under various scenarios.
Phase 4: Documentation

Consolidate & Update Documentation:
Task:
Replace the content of docs/implementation_plan.md with this finalized prompt/plan.
Thoroughly update docs/supabase-rls-policies.md to accurately reflect all implemented helper functions and RLS policies for every table. Make this the single source of truth for RLS.
Review docs/example.md for any unique concepts not captured elsewhere, migrate them to supabase-rls-policies.md or as comments in .sql files, and then archive or delete docs/example.md.
Document the SECURITY DEFINER functions, explaining their purpose, the data they return, and detailing their internal security checks.
Rationale: Ensures project documentation is accurate, up-to-date, and maintainable.

Analyze all
c:\Developer\supabase\schemas

AND @rbac-implementation-plan.md 
and @docs/register-process 
and @supabase-rls-policies.md 
@example.md 
@README.md 
@supabase.types.ts 


Propose the database functions, tables and triggers needed to implement the dashboard.

-------------- PROPOSAL 2ND PART ----------------
Questions for Dashboard & BI Design
A. Organization-wide (Superadmin / General Director)
How many active agreements were created this month versus the same month last year?
How many agreements have been created this year?
In which headquarter have the most agreements been created this year?
When are the most agreements created?

What is the trend of active students per quarter for each headquarter?

What percentage of agreements are active?
What percentage of agreements are prospect?
How fast are agreements moving from “prospect” to “active” status on average?

B. Headquarter Manager
How many students are currently enrolled in all headquarter?
How many students are currently enrolled by country?
Which events had the highest no-show rate last season?
Are any facilitators overloaded ( > N workshops per season) in my HQ?


C. Pedagogical / Executive Leaders
Which headquarters have the best student-graduation ratio in the last 12 months?
What proportion of facilitators hold multiple roles across headquarters?

E. Operational (Companions / Facilitators)
Which of my assigned students have not attended an event in the past 5 workshops?

F. Students (Self-service)
What is my attendance rate?
(Feel free to expand or refine as new schema entities appear.)

Next steps
(Optional) create helper mapping tables (companion_student_map, etc.).

- In which headquarter have the most agreements been created this year?


As a manager of a headquarter i need to know:
- How many students are currently enrolled in my HQ?
- How many collaborators are currently enrolled in my HQ?
- Age distribution of students
- Age distribution of collaborators
- Gender distribution of students
- Gender distribution of collaborators
- How many manager assistants or role level > 1 are currently enrolled in my HQ?
- How many agreements have been created in my HQ this year?
- How many agreements have been created in my HQ in the past 3 months?
- How many agreements are active
- How many agreements are prospect
- How many agreements are inactive
- When are the most agreements created? // how to analyze this?
- What percentage of agreements are active?
- What percentage of agreements are prospect?

Total quantity of agreements and percentage distribution by role, gruped by facilitator, companion, students, other than poses role level more than the  already mentioned
- How fast are agreements moving from “prospect” to “active” status on average? // this one is really good

As a student i need to know:
- What is my attendance rate? (workshops)
- How many companion hours have I enjoyed this season?
- My workshops schedule
- The info of my companion
- The info of my facilitators

As a companion i need to know:
- Which of my assigned students have not attended an event in the past 5 workshops?
- the info of my assigned students


As a pedagogical leader i need to know:
- Which headquarters have the best student-graduation ratio in the last 12 months?
- What proportion of facilitators hold multiple roles across headquarters?

As a general director i need to know:
- How many active agreements were created this month versus the same month last year?
- How many agreements have been created this year?
- In which headquarter have the most agreements been created this year?
- When are the most agreements created?
- What is the trend of active students per quarter for each headquarter?
- What percentage of agreements are active?
- What percentage of agreements are prospect?
- How fast are agreements moving from “prospect” to “active” status on average?

-------------- PROPOSAL 2ND PART ----------------



------ OLD DOCUMENTATION FOR CONTEXT ----------------

/* ---------- AGREEMENTS ---------- */
-- PERMISSIVE policies, one per verb
CREATE POLICY "Agmts-select: same HQ or high level"
ON agreements
FOR SELECT
TO authenticated
USING (
  fn_current_role_level() >= 80
  OR headquarter_id IN (
        SELECT hq_id
        FROM user_headquarter_map          -- ← optional helper table do we really need it? we can get this info with a function
        WHERE user_id = auth.uid()
     )
);

Agmts-insert: shouldnt have policy because we need to register new prospects there and they should be able to do it anonimously.


CREATE POLICY "Agmts-delete: ≥ superadmin"
ON agreements
FOR DELETE
TO authenticated
USING ( fn_current_role_level() >=80 );

also create a trigger that before deleting sending it to a audit table so we never loose agreements data...

/* ---------- STUDENTS ---------- */
explain this one 

CREATE POLICY "Std-select: self / companion / HQ / high"
ON students
FOR SELECT
TO authenticated
USING (
      user_id = auth.uid()                                 -- student
  OR  fn_current_role_code() IN ('companion','facilitator') -- mentor
  OR  headquarter_id IN (SELECT hq_id FROM user_headquarter_map WHERE user_id = auth.uid())
  OR  fn_current_role_level() >= 80
);

CREATE POLICY "Std-insert: ≥ manager"
ON students
FOR INSERT
TO authenticated
WITH CHECK ( fn_current_role_level() >= 40 );

CREATE POLICY "Std-update: ≥ manager OR mentor of student"
ON students
FOR UPDATE
TO authenticated
USING (
      fn_current_role_level() >= 40
  OR (fn_current_role_code() IN ('companion','facilitator')
      AND id IN (SELECT student_id FROM mentor_student_map WHERE mentor_id = auth.uid()))
)
WITH CHECK ( fn_current_role_level() >= 40 );

CREATE POLICY "Std-delete: ≥ superadmin"
ON students
FOR DELETE
TO authenticated
USING ( fn_current_role_level() = 100 );

/* ---------- HEADQUARTERS ---------- */
CREATE POLICY "HQ-select: everyone"
ON headquarters
FOR SELECT
TO authenticated
USING ( true );

CREATE POLICY "HQ-insert/update/delete: ≥ general_director"
ON headquarters
FOR INSERT TO authenticated WITH CHECK ( fn_current_role_level() >= 80 );
CREATE POLICY "HQ-update"
ON headquarters
FOR UPDATE TO authenticated
USING ( fn_current_role_level() >= 80 )
WITH CHECK ( fn_current_role_level() >= 80 );
CREATE POLICY "HQ-delete"
ON headquarters
FOR DELETE TO authenticated
USING ( fn_current_role_level() >= 100 );

/* ---------- COLLABORATORS, WORKSHOPS, EVENTS ---------- */
-- Same template: allow people in the same HQ OR any role ≥ 80
CREATE POLICY "Collab/Ev/Wk-select: same HQ or high"
ON collaborators  FOR SELECT TO authenticated USING (
  headquarter_id IN (SELECT hq_id FROM user_headquarter_map WHERE user_id = auth.uid())
  OR fn_current_role_level() >= 80
);
-- repeat insert/update/delete with appropriate ≥ lvl checks …
Explanations
•  functions let every policy stay readable.
• All policies are “PERMISSIVE”, so multiple policies can coexist without unexpected lock-outs.
• Indexes on headquarter_id and any extra mapping table are already in place, satisfying the performance advice.

2. Dashboard / Analytics Functions
sql

/* ---------- Global statistics (Superadmin, Gen-Director) ---------- */
this functions is poor should return a lot more data...
CREATE OR REPLACE FUNCTION get_global_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER

AS $$
DECLARE
  v_students  bigint;
  v_active_ag bigint;
  v_hq        bigint;
BEGIN
  SELECT COUNT(*) INTO v_students  FROM students      WHERE status='active';
  SELECT COUNT(*) INTO v_active_ag FROM agreements    WHERE status='active';
  SELECT COUNT(*) INTO v_hq        FROM headquarters  WHERE status='active';

  RETURN jsonb_build_object(
    'total_students',  v_students,
    'active_agreements', v_active_ag,
    'headquarters',    v_hq
  );
END;
$$;

/* ---------- HQ-specific statistics (HQ Manager & Leaders) ---------- */
this functions is poor should return a lot more data...
CREATE OR REPLACE FUNCTION get_headquarter_dashboard_stats(p_hq uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_hq uuid := COALESCE(p_hq,
      (SELECT hq_id FROM user_headquarter_map WHERE user_id = auth.uid() LIMIT 1));
  v_students int;
  v_collabs  int;
  v_events   int;
BEGIN
  SELECT COUNT(*) INTO v_students FROM students      WHERE headquarter_id = v_hq;
  SELECT COUNT(*) INTO v_collabs  FROM collaborators WHERE headquarter_id = v_hq AND status='active';
  SELECT COUNT(*) INTO v_events   FROM events        WHERE headquarter_id = v_hq AND start_datetime >= NOW();

  RETURN jsonb_build_object(
    'hq_id',          v_hq,
    'students',       v_students,
    'active_staff',   v_collabs,
    'upcoming_events',v_events
  );
END;
$$;

/* ---------- User-centric statistics (Student, Companion, Facilitator) ---------- */
explain the utility of this one
CREATE OR REPLACE FUNCTION get_user_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_role text := fn_current_role_code();
  v_ag   uuid;
  v_ws   int;
  v_ev   int;
BEGIN
  SELECT agreement_id INTO v_ag FROM students WHERE user_id = auth.uid() LIMIT 1;

  SELECT COUNT(*) INTO v_ws FROM workshops
    WHERE (facilitator_id = auth.uid() OR id IN (
      SELECT workshop_id FROM workshop_participants WHERE user_id = auth.uid()
    ))
      AND start_datetime >= NOW();

  SELECT COUNT(*) INTO v_ev FROM events
    WHERE id IN (SELECT event_id FROM event_participants WHERE user_id = auth.uid())
      AND start_datetime >= NOW();

  RETURN jsonb_build_object(
    'role',              v_role,
    'agreement_id',      v_ag,
    'upcoming_workshops',v_ws,
    'upcoming_events',   v_ev
  );
END;
$$;

/* ---------- Latest five agreements & pending actions ---------- */
CREATE OR REPLACE FUNCTION get_latest_agreements(p_limit int DEFAULT 5)
RETURNS TABLE (
  id uuid,
  name text,
  role text,
  status text,
  created_at timestamptz
)
LANGUAGE sql
SECURITY INVOKER
AS $$
  SELECT a.id, a.name, r.name AS role, a.status, a.created_at
  FROM agreements a
  JOIN roles r ON r.id = a.role_id
  ORDER BY a.created_at DESC
  LIMIT p_limit;
$$;
All functions are “SECURITY INVOKER” so RLS automatically scopes the data.

3. Auditing (triggers + helper table)
4. this is interesting and necessary
sql
/* ---------- 1)  Generic audit table ---------- */
CREATE TABLE audit_log (
  id            bigserial PRIMARY KEY,
  table_name    text,
  action        text,          -- 'INSERT' | 'UPDATE' | 'DELETE'
  record_id     uuid,
  changed_by    uuid,
  user_name text
  changed_at    timestamptz DEFAULT now(),
  diff          jsonb
);

/* ---------- 2)  Re-usable trigger function ---------- */
CREATE OR REPLACE FUNCTION trg_audit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    INSERT INTO audit_log(table_name, action, record_id, changed_by, diff)
    VALUES (TG_TABLE_NAME, TG_OP, OLD.id, auth.uid(), to_jsonb(OLD));
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    INSERT INTO audit_log(table_name, action, record_id, changed_by, diff)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, auth.uid(),
            jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW)));
    RETURN NEW;
  ELSE  -- INSERT
    INSERT INTO audit_log(table_name, action, record_id, changed_by, diff)
    VALUES (TG_TABLE_NAME, TG_OP, NEW.id, auth.uid(), to_jsonb(NEW));
    RETURN NEW;
  END IF;
END;
$$;

/* ---------- 3)  Attach trigger to critical tables ---------- */
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['agreements','students','collaborators','headquarters','countries','seasons','workshops']
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS audit_%I ON %I;
      CREATE TRIGGER audit_%I
      AFTER INSERT OR UPDATE OR DELETE ON %I
      FOR EACH ROW EXECUTE PROCEDURE trg_audit();',
      t, t, t, t);
  END LOOP;
END;
$$;

------ OLD DOCUMENTATION FOR CONTEXT ----------------
