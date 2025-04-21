-- Collaborators table definition
CREATE TABLE collaborators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NULL, -- Allow NULL for development
    agreement_id UUID REFERENCES agreements(id) ON DELETE CASCADE,
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
