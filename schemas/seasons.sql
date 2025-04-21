-- Seasons table definition
CREATE TABLE seasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    headquarter_id UUID REFERENCES headquarters(id) ON DELETE CASCADE,
    manager_id UUID NULL, -- Allow NULL during development
    start_date DATE,
    end_date DATE,
    status TEXT CHECK (status IN ('active', 'inactive', 'planning', 'completed')) DEFAULT 'planning',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TRIGGER handle_updated_at_seasons
    BEFORE UPDATE ON seasons
    FOR EACH ROW EXECUTE PROCEDURE moddatetime(updated_at);

CREATE INDEX idx_seasons_headquarter_id ON seasons(headquarter_id);
CREATE INDEX idx_seasons_manager_id ON seasons(manager_id);
