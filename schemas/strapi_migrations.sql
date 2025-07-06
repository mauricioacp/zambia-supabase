CREATE TABLE strapi_migrations (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    migration_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_migrated_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
    records_processed INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add comment to the table
COMMENT ON TABLE strapi_migrations IS 'Tracks Strapi to Supabase migration runs';

-- Add comments to columns
COMMENT ON COLUMN strapi_migrations.id IS 'Unique identifier for each migration run';
COMMENT ON COLUMN strapi_migrations.migration_timestamp IS 'When the migration was executed';
COMMENT ON COLUMN strapi_migrations.last_migrated_at IS 'Timestamp of the last successfully migrated record';
COMMENT ON COLUMN strapi_migrations.status IS 'Status of the migration (success/failed)';
COMMENT ON COLUMN strapi_migrations.records_processed IS 'Number of records processed in this migration';
COMMENT ON COLUMN strapi_migrations.error_message IS 'Error message if migration failed';
COMMENT ON COLUMN strapi_migrations.created_at IS 'When this record was created';

-- Add RLS policies
ALTER TABLE strapi_migrations ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view migration history
CREATE POLICY "Allow authenticated users to view migration history" 
ON strapi_migrations FOR SELECT 
TO authenticated 
USING (true);

-- Allow service role to insert new migration records
CREATE POLICY "Allow service role to insert migration records" 
ON strapi_migrations FOR INSERT 
TO service_role 
WITH CHECK (true);