-- ClickHouse Schema Initialization
-- Databases for different layers

-- Raw layer: Direct ingestion from sources
CREATE DATABASE IF NOT EXISTS raw;

-- Staging layer: Initial transformations
CREATE DATABASE IF NOT EXISTS staging;

-- Analytics layer: Core business logic
CREATE DATABASE IF NOT EXISTS analytics;

-- Master data: Entity resolution results
CREATE DATABASE IF NOT EXISTS master_data;

-- Egress layer: Prepared for export
CREATE DATABASE IF NOT EXISTS egress;

-- Example table with ClickHouse best practices
CREATE TABLE IF NOT EXISTS raw.events (
    event_id UUID DEFAULT generateUUIDv4(),
    event_time DateTime64(3),
    user_id UInt64,
    event_type LowCardinality(String),
    properties String  -- JSON
) ENGINE = MergeTree()
ORDER BY (event_time, user_id)
PARTITION BY toYYYYMM(event_time)
SETTINGS index_granularity = 8192;

SELECT 'ClickHouse schema initialized successfully!' as status;
