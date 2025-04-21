-- Events table definition
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    location JSONB,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft'
);

CREATE TRIGGER handle_updated_at_events
    BEFORE UPDATE ON events
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_events_headquarter_id ON events(headquarter_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_start_datetime ON events(start_datetime);

-- Enable Row Level Security
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
-- SELECT policy
CREATE POLICY "Allow authenticated users to view events"
ON events
FOR SELECT
TO authenticated
USING (true);

-- INSERT policy
CREATE POLICY "Allow authenticated users to insert events"
ON events
FOR INSERT
TO authenticated
WITH CHECK (true);

-- UPDATE policy
CREATE POLICY "Allow authenticated users to update events"
ON events
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- DELETE policy
CREATE POLICY "Allow authenticated users to delete events"
ON events
FOR DELETE
TO authenticated
USING (true);
