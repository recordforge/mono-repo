-- PostgreSQL Schema Initialization
-- Databases/schemas for different layers

-- Create schemas for different data layers
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS master_data;
CREATE SCHEMA IF NOT EXISTS egress;

-- Grant permissions to the default user
GRANT ALL PRIVILEGES ON SCHEMA raw TO dataplatform;
GRANT ALL PRIVILEGES ON SCHEMA staging TO dataplatform;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO dataplatform;
GRANT ALL PRIVILEGES ON SCHEMA master_data TO dataplatform;
GRANT ALL PRIVILEGES ON SCHEMA egress TO dataplatform;

-- Set search path to include all schemas
ALTER DATABASE dataplatform SET search_path TO public, raw, staging, analytics, master_data, egress;

-- Create test data table based on Splink demo dataset
CREATE TABLE IF NOT EXISTS raw.person_records (
    unique_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100),
    surname VARCHAR(100),
    dob DATE,
    city VARCHAR(100),
    email VARCHAR(200),
    cluster INTEGER
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_person_first_name ON raw.person_records(first_name);
CREATE INDEX IF NOT EXISTS idx_person_surname ON raw.person_records(surname);
CREATE INDEX IF NOT EXISTS idx_person_dob ON raw.person_records(dob);
CREATE INDEX IF NOT EXISTS idx_person_city ON raw.person_records(city);
CREATE INDEX IF NOT EXISTS idx_person_email ON raw.person_records(email);
CREATE INDEX IF NOT EXISTS idx_person_cluster ON raw.person_records(cluster);

-- Example events table for general data ingestion
CREATE TABLE IF NOT EXISTS raw.events (
    event_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    user_id BIGINT NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    properties JSONB
);

-- Create index for events table
CREATE INDEX IF NOT EXISTS idx_events_time ON raw.events(event_time);
CREATE INDEX IF NOT EXISTS idx_events_user ON raw.events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON raw.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_properties ON raw.events USING GIN (properties);

SELECT 'PostgreSQL schema initialized successfully!' as status;