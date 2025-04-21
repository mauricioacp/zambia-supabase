-- Workshops table definition
CREATE TABLE workshops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE SET NULL,
    season_id UUID REFERENCES seasons(id) ON DELETE SET NULL,
    start_datetime TIMESTAMPTZ,
    end_datetime TIMESTAMPTZ,
    facilitator_id UUID REFERENCES collaborators(id) ON DELETE SET NULL,
    capacity INTEGER,
    status TEXT CHECK (status IN ('draft', 'scheduled', 'completed', 'cancelled')) DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_workshops
    BEFORE UPDATE ON workshops
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_workshops_headquarter_id ON workshops(headquarter_id);
