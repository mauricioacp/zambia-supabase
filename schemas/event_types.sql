-- schemas/event_types.sql

CREATE TABLE event_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    title TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ
);

COMMENT ON TABLE event_types IS 'Defines the categories or types of events.';
CREATE INDEX idx_event_types_name ON event_types(name); -- Support fast lookup by name
-- SUGGESTION: If status or similar field is added, consider ENUM for type safety.
COMMENT ON COLUMN event_types.name IS 'Unique name for the event type (e.g., ''Companion Activity'', ''HQ Meeting'').';
COMMENT ON COLUMN event_types.description IS 'Optional longer description of the event type.';
COMMENT ON COLUMN event_types.title IS 'Title for the event type.';

CREATE TRIGGER handle_updated_at_event_types
    BEFORE UPDATE ON event_types
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

ALTER TABLE event_types ENABLE ROW LEVEL SECURITY;


-- SELECT: Allow all authenticated users to view event types
CREATE POLICY event_types_select_authenticated
ON event_types FOR SELECT
TO authenticated
USING (true);

-- INSERT: Restrict to Konsejo Member+ (or adjust level as needed)
CREATE POLICY event_types_insert_high_level
ON event_types FOR INSERT
WITH CHECK ( fn_is_konsejo_member_or_higher() );

-- UPDATE: Restrict to Konsejo Member+
CREATE POLICY event_types_update_high_level
ON event_types FOR UPDATE
USING ( fn_is_konsejo_member_or_higher() )
WITH CHECK ( fn_is_konsejo_member_or_higher() );

-- DELETE: Restrict to Konsejo Member+ (or perhaps Super Admin)
CREATE POLICY event_types_delete_high_level
ON event_types FOR DELETE
USING ( fn_is_konsejo_member_or_higher() );
