-- schemas/workshop_triggers.sql

-- Function to check if a user is a valid facilitator for a given HQ
-- Assumes 'collaborators' table links user_id to role_id and headquarter_id
CREATE OR REPLACE FUNCTION fn_is_valid_facilitator_for_hq(p_user_id uuid, p_headquarter_id uuid)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
    is_valid boolean := false;
    facilitator_role_level integer := 20;
BEGIN
    -- Check if a collaborator exists, belongs to the HQ, and has the facilitator role level
    SELECT EXISTS (
        SELECT 1
        FROM public.collaborators c
        JOIN public.roles r ON c.role_id = r.id
        WHERE c.user_id = p_user_id
          AND c.headquarter_id = p_headquarter_id
          AND r.level >= facilitator_role_level
    ) INTO is_valid;
    RETURN is_valid;
END;
$$;

COMMENT ON FUNCTION fn_is_valid_facilitator_for_hq(uuid, uuid) IS 'Checks if a given user_id is a collaborator with facilitator role level (or higher) within the specified headquarter_id.';

-- Trigger function to validate facilitator on workshop schedule/update
CREATE OR REPLACE FUNCTION trigger_validate_workshop_facilitator()
RETURNS TRIGGER 
SET search_path = ''
AS $$
BEGIN
    -- Check on INSERT or if facilitator_id or headquarter_id is changed on UPDATE
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (NEW.facilitator_id IS DISTINCT FROM OLD.facilitator_id OR NEW.headquarter_id IS DISTINCT FROM OLD.headquarter_id)) THEN
        IF NOT public.fn_is_valid_facilitator_for_hq(NEW.facilitator_id, NEW.headquarter_id) THEN
            RAISE EXCEPTION 'User ID % is not a valid facilitator for headquarter ID %.', NEW.facilitator_id, NEW.headquarter_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION trigger_validate_workshop_facilitator() IS 'Trigger function for scheduled_workshops table to ensure the assigned facilitator_id is valid for the specified headquarter_id.';

DROP TRIGGER IF EXISTS validate_facilitator_before_insert_update ON scheduled_workshops;

CREATE TRIGGER validate_facilitator_before_insert_update
    BEFORE INSERT OR UPDATE ON scheduled_workshops
    FOR EACH ROW EXECUTE FUNCTION trigger_validate_workshop_facilitator();

GRANT EXECUTE ON FUNCTION fn_is_valid_facilitator_for_hq(uuid, uuid) TO authenticated;
