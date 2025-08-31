# PostgreSQL CDC Egress Tool - Architecture Design

## Executive Summary

A Rust-based Change Data Capture (CDC) tool designed for micro-batch ETL processing. The tool connects to PostgreSQL logical replication slots, processes database changes in configurable batches, compresses all output files, and maintains a detailed file registry in PostgreSQL for downstream ETL processes (like Snowflake ingestion). The system supports Kubernetes deployment and single-table reload coordination using DDL comments.

## System Purpose

This tool is optimized for micro-batch ETL workflows rather than real-time streaming. It focuses on:
- Predictable batch intervals for downstream processing
- Compressed file outputs to minimize storage costs
- Simple, consistent folder structure for easy consumption
- Detailed file registry for ETL orchestration
- CSV format all records written to the file system

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                     PostgreSQL Database                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Tables     │  │  Replication │  │  File Registry│     │
│  │              │  │     Slot     │  │     Table     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│              CDC Egress Tool (Micro-batch ETL)              │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │          Connection & Replication Manager           │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │              WAL Stream Processor                   │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │            Micro-batch Controller                   │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │           Table Metadata Registry                   │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Table Reload Coordinator                    │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │         File Compression & Output Manager           │     │
│  └────────────────────────────────────────────────────┘     │
│                          │                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │           File Registry Publisher                   │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                    Compressed File Storage                   │
│                                                              │
│  Simple Structure: /data/<table>/<timestamp>/files.gz        │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│           Downstream ETL Process (e.g., Snowflake)          │
│                                                              │
│  Queries file registry → Reads compressed files → Ingests   │
└─────────────────────────────────────────────────────────────┘
```

## File Organization Strategy

### Simple Folder Structure

```
/data/
├── public.users/                    ← Table name (schema.table)
│   ├── 2025-01-15T10-00-00/
│   │   ├── schema.yml               ← Table DDL (only for full_reload)
│   │   └── full_reload.csv.gz      ← Full table export
│   ├── 2025-01-15T10-05-00/
│   │   └── streaming.csv.gz      ← Incremental changes
│   ├── 2025-01-15T10-10-00/
│   │   └── streaming.csv.gz
│   └── ...
│
├── public.orders/
│   ├── 2025-01-15T10-00-00/
│   │   ├── schema.yml
│   │   └── full_reload.csv.gz
│   ├── 2025-01-15T10-05-00/
│   │   └── streaming.csv.gz
│   └── ...
│
└── analytics.events/
    └── ...
```

### File Naming Conventions

```
Full Reload Files:
- schema.yml                 # Table DDL definition
- full_reload.csv.gz         # Complete table data in CSV

Streaming Files:
- streaming.csv.gz           # CDC data changes in CSV format
- ddl.txt                    # DDL changes if any (CREATE, ALTER, DROP)
```

## Detailed Workflows

### 1. Micro-batch Processing for Streaming

```
Streaming Mode Batch Processing
    │
    ▼
Start New Batch at 10:05:00
    │
    ▼
Read WAL Stream for 5 minutes
    │
    ▼
Buffer Changes by Table:
- public.users: 1,250 changes
- public.orders: 3,420 changes
- analytics.events: 890 changes
    │
    ▼
At 10:10:00 or size limit:
    │
    ▼
For Each Table with Changes:
    │
    ├── Create timestamp directory:
    │   /data/public.users/2025-01-15T10-05-00/
    │
    ├── Separate DDL from DML:
    │   - Filter INSERTs to public.ddl_history
    │   - Group regular data changes
    │
    ├── Write data file:
    │   - Format DML changes as CSV
    │   - Stream through gzip compression
    │   - Write as streaming.csv.gz
    │
    ├── Write DDL file (if any):
    │   - Extract DDL commands from ddl_history inserts
    │   - Write as plain text ddl.txt
    │   - Include timestamp and object info
    │
    └── Register in Database File Registry:
        - Record all metadata in cdc_registry.file_log
        - Track LSN positions, row counts, DDL presence
        - Update table state as needed
    │
    ▼
Flush LSN after all files written
    │
    ▼
Start Next Batch
```

### 2. Table Reload Coordination Using DDL Comments

#### The Core Challenge

In streaming CDC mode, we need to occasionally perform full table reloads while maintaining:
- Continuous streaming for all other tables
- Exact LSN coordination to prevent data loss or duplication
- Clear boundaries between streaming and reload operations
- Crash-safe recovery mechanisms

#### The Solution: DDL Comments as WAL Markers

PostgreSQL's logical replication captures DDL statements (including COMMENT ON TABLE) in the WAL stream at specific LSNs. This creates natural coordination points that our CDC infrastructure already processes.

```
Table Reload Coordination Flow
    │
    ▼
Phase 1: Initiate Reload (External Trigger)
    │
    ├── API call, monitoring alert, or manual intervention
    └── Execute DDL comment as coordination marker:
        COMMENT ON TABLE public.users IS 
        'CDC_RELOAD: {
          "action": "EXPORT_START",
          "export_id": "uuid-12345",
          "table_name": "public.users",
          "timestamp": "2025-01-15T10:30:00Z"
        }'
    │
    ▼
Phase 2: CDC Tool Detection (In WAL Stream)
    │
    ├── WAL processor encounters DDL comment at LSN 0/1A2B3C4D
    ├── Parse comment content for CDC_RELOAD marker
    └── Extract coordination metadata:
        - Export ID for tracking
        - Table identity
        - Start LSN position
    │
    ▼
Phase 3: Export Coordination
    │
    ├── CDC Tool Actions:
    │   ├── Complete current streaming batch for table
    │   ├── Flush LSN to establish checkpoint
    │   ├── Mark table state as "reload_in_progress"
    │   └── Store export_id and start_lsn
    │
    ├── Delta Tracking Strategy:
    │   ├── Continue processing WAL stream
    │   ├── Buffer changes for reload table separately
    │   └── Track delta_start_lsn = 0/1A2B3C4D
    │
    ▼
Phase 4: Table Export Process (Independent)
    │
    ├── Use consistent snapshot at START marker LSN
    ├── Query table schema:
    │   SELECT column_name, data_type, is_nullable, 
    │          column_default, character_maximum_length
    │   FROM information_schema.columns
    │   WHERE table_schema = 'public' 
    │     AND table_name = 'users'
    │
    ├── Generate schema.yml with version tracking
    │
    ├── Export table data:
    │   BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
    │   SET TRANSACTION SNAPSHOT <snapshot_at_start_lsn>;
    │   COPY public.users TO STDOUT WITH CSV HEADER;
    │   COMMIT;
    │
    ├── Compress to full_reload.csv.gz
    │
    ├── Create timestamped directory:
    │   /data/public.users/2025-01-15T10-30-00/
    │
    └── Write files atomically:
        - schema.yml
        - full_reload.csv.gz
    │
    ▼
Phase 5: Delta Management During Export
    │
    ├── CDC continues processing all tables
    ├── For reload table, delta changes are:
    │   Option 1: Buffered in memory/disk
    │   Option 2: Written to separate delta files
    │   Option 3: Counted but discarded
    │
    └── Delta tracking metadata:
        - delta_count: 342
        - delta_lsn_range: 0/1A2B3C4D to current
    │
    ▼
Phase 6: Export Completion Signal
    │
    └── Execute END marker:
        COMMENT ON TABLE public.users IS 
        'CDC_RELOAD: {
          "action": "EXPORT_END",
          "export_id": "uuid-12345",
          "table_name": "public.users",
          "timestamp": "2025-01-15T10:35:00Z",
          "rows_exported": 250000
        }'
    │
    ▼
Phase 7: CDC Tool Finalization
    │
    ├── Detect END marker at LSN 0/1A2B3C7F
    ├── Validate export_id matches START marker
    ├── Update reload operation status:
    │   UPDATE cdc_registry.reload_operations
    │   SET end_marker_lsn = '0/1A2B3C7F',
    │       status = 'completed'
    │   WHERE export_id = 'uuid-12345'
    │
    └── Delta reconciliation decision:
        ├── If delta_strategy = 'discard':
        │   └── Drop buffered changes
        ├── If delta_strategy = 'apply':
        │   └── Write delta file with changes
        └── If delta_strategy = 'validate':
            └── Compare counts for monitoring
    │
    ▼
Phase 8: Resume Normal Streaming
    │
    ├── Clear reload state for table
    ├── Resume normal CDC processing
    └── Continue with next batch
```

#### LSN Management Strategy

```
LSN Flushing During Reload
    │
    ├── Before START marker:
    │   └── Normal flushing behavior
    │
    ├── At START marker detection:
    │   ├── Immediate flush to checkpoint
    │   └── Record: reload_checkpoint_lsn
    │
    ├── During export (critical period):
    │   ├── Option 1: Hold flushes
    │   │   - Accumulates WAL on PostgreSQL
    │   │   - Safest for recovery
    │   │
    │   ├── Option 2: Flush with tracking
    │   │   - Continue flushing
    │   │   - Maintain delta buffer
    │   │   - Track flushed positions
    │   │
    │   └── Option 3: Selective flushing
    │       - Flush other tables normally
    │       - Hold reload table position
    │
    └── After END marker:
        └── Resume normal flushing
```

#### Crash Recovery Scenarios

```
Recovery State Machine
    │
    ├── Crash before START marker:
    │   └── No special handling needed
    │
    ├── Crash after START, before export:
    │   ├── Detect incomplete reload in registry
    │   ├── Check for START marker in WAL
    │   └── Either retry or cancel reload
    │
    ├── Crash during export:
    │   ├── Detect partial files
    │   ├── Check export_id in registry
    │   ├── Clean up partial files
    │   └── Retry from START marker LSN
    │
    ├── Crash after export, before END:
    │   ├── Detect completed files
    │   ├── Verify file integrity
    │   ├── Check for END marker
    │   └── Complete or retry END marker
    │
    └── Crash after END marker:
        └── Normal recovery, reload complete
```

#### Multiple Table Coordination

```
Concurrent Reload Support
    │
    ├── Table Independence:
    │   ├── Each table has separate export_id
    │   ├── Non-overlapping LSN ranges
    │   └── Independent state tracking
    │
    ├── Resource Management:
    │   ├── Limit concurrent reloads
    │   ├── Queue additional requests
    │   └── Monitor system resources
    │
    └── Example Timeline:
        10:00 - public.users START
        10:02 - public.orders START
        10:05 - public.users END
        10:07 - public.orders END
```

### 3. Full Table Reload Implementation Details

```
Full Table Reload Process
    │
    ▼
External Process Executes START Marker:
COMMENT ON TABLE public.users IS 
'CDC_RELOAD: {"action":"EXPORT_START","export_id":"uuid-12345"}'
    │
    ▼
CDC Tool Detects Marker
    │
    ├── Complete current streaming batch
    ├── Flush LSN
    └── Mark table as "in_reload"
    │
    ▼
External Export Process:
    │
    ├── Query table schema:
    │   SELECT column_name, data_type, is_nullable, 
    │          column_default, character_maximum_length
    │   FROM information_schema.columns
    │   WHERE table_schema = 'public' 
    │     AND table_name = 'users'
    │
    ├── Generate schema.yml:
    │   table: public.users
    │   columns:
    │     - name: id
    │       type: bigint
    │       nullable: false
    │       primary_key: true
    │     - name: email
    │       type: varchar(255)
    │       nullable: false
    │     - name: created_at
    │       type: timestamp
    │       nullable: false
    │
    ├── Export table data as CSV:
    │   COPY public.users TO STDOUT WITH CSV HEADER
    │
    ├── Compress to full_reload.csv.gz
    │
    ├── Create directory:
    │   /data/public.users/2025-01-15T10-30-00/
    │
    ├── Write files:
    │   - schema.yml
    │   - full_reload.csv.gz
    │
    └── Register in File Registry
    │
    ▼
External Process Executes END Marker
    │
    ▼
CDC Tool resumes normal streaming for table
```

### 4. File Registry for ETL Coordination

```
File Registration Flow
    │
    ▼
After Writing Files:
/data/public.users/2025-01-15T10-05-00/streaming.csv.gz
    │
    ▼
Register in PostgreSQL (Minimal):

INSERT INTO cdc_registry.file_log (
    table_name,
    batch_timestamp,
    file_path,
    file_type,
    end_lsn,
    row_count
) VALUES (
    'public.users',
    '2025-01-15T10:05:00',
    '/data/public.users/2025-01-15T10-05-00/streaming.csv.gz',
    'streaming',
    '0/1A2B3C7F',  -- Last LSN in this batch
    1250
);
    │
    ▼
Update Table State:

UPDATE cdc_registry.table_state
SET last_streaming_lsn = '0/1A2B3C7F',
    updated_at = NOW()
WHERE table_name = 'public.users'
  AND current_mode = 'streaming';
    │
    ▼
Downstream ETL Query:

-- Get latest files since last LSN
SELECT 
    table_name,
    batch_timestamp,
    file_path,
    file_type,
    end_lsn,
    row_count
FROM cdc_registry.file_log
WHERE table_name = 'public.users'
  AND end_lsn > :last_processed_lsn
ORDER BY end_lsn;
```

### 5. Compression Strategy

```
Compression Pipeline
    │
    ▼
Determine File Type:
    │
    ├─[Full Reload]
    │   ├── Format: CSV (faster parsing)
    │   ├── Compression: gzip -9 (max compression)
    │   └── Include schema.yml
    │
    └─[Streaming]
        ├── Format: CSV (includes change metadata columns)
        ├── Compression: gzip -6 (balanced)
        └── No schema file needed
    │
    ▼
Write Process:
    │
    ├── Open output file
    ├── Pipe through compressor
    ├── Calculate SHA256 during write
    ├── Atomic rename when complete
    └── Verify integrity
```

## Database Schema

### File Registry Tables (Excluded from Replication)

**IMPORTANT**: All CDC registry tables must be excluded from logical replication to prevent circular dependencies. Create these tables in a separate schema (e.g., `cdc_registry`) that is not part of the publication.

```sql
-- Create dedicated schema for CDC registry (excluded from replication)
CREATE SCHEMA IF NOT EXISTS cdc_registry;

-- Minimal file tracking for WAL position management
CREATE TABLE cdc_registry.file_log (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,              -- Full table name (schema.table)
    batch_timestamp TIMESTAMP NOT NULL,     -- Maps to folder name
    file_path TEXT NOT NULL,                -- Full path to file
    file_type VARCHAR(20) NOT NULL,         -- 'streaming', 'full_reload', or 'ddl'
    end_lsn PG_LSN NOT NULL,                -- Last LSN in this file
    row_count INT NOT NULL,                 -- Number of rows (0 for DDL files)
    has_ddl BOOLEAN DEFAULT FALSE,          -- TRUE if batch contains DDL changes
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Single composite index for common queries
    INDEX idx_table_lsn (table_name, end_lsn DESC)
);

-- Table state tracker (streaming vs reload mode)
CREATE TABLE cdc_registry.table_state (
    table_name TEXT PRIMARY KEY,            -- Full table name (schema.table)
    current_mode VARCHAR(20) NOT NULL,      -- 'streaming' or 'reloading'
    last_streaming_lsn PG_LSN,              -- Last LSN processed in streaming
    reload_export_id UUID,                  -- Current reload operation ID (if any)
    reload_start_lsn PG_LSN,                -- LSN where reload started
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Active reload operations (minimal tracking)
CREATE TABLE cdc_registry.reload_operations (
    export_id UUID PRIMARY KEY,
    table_name TEXT NOT NULL,
    start_marker_lsn PG_LSN NOT NULL,       -- LSN of START comment
    end_marker_lsn PG_LSN,                  -- LSN of END comment (when complete)
    status VARCHAR(20) NOT NULL,            -- 'active' or 'completed'
    created_at TIMESTAMP DEFAULT NOW()
);

-- Example: Exclude registry schema from publication
-- ALTER PUBLICATION cdc_publication SET (publish = 'insert, update, delete');
-- ALTER PUBLICATION cdc_publication ADD ALL TABLES IN SCHEMA public, analytics 
--   EXCEPT ALL TABLES IN SCHEMA cdc_registry;
```

## Configuration Schema

```yaml
connection:
  host: <postgresql-host>
  port: 5432
  database: <database-name>
  username: <replication-user>
  password_secret: <k8s-secret-name>
  
replication:
  slot_name: cdc_egress_slot
  publication_name: cdc_publication
  # Publication must exclude cdc_registry schema
  
batch_control:
  interval_minutes: 5  # New batch every 5 minutes
  max_batch_size_mb: 500
  max_batch_rows: 1000000
  
output:
  base_path: /data
  
  # File formats
  streaming_format: csv  # CDC changes
  full_reload_format: csv  # Full exports (faster parsing)
  
  # Compression (all files compressed)
  compression:
    algorithm: gzip  # gzip or zstd
    level: 6  # 1-9 for gzip
  
  # Simple folder structure
  folder_pattern: "{schema}.{table}/{timestamp}"
  timestamp_format: "YYYY-MM-DDTHH-mm-ss"
  
tables:
  include_schemas:
    - public
    - analytics
  exclude_schemas:
    - pg_catalog
    - information_schema
    - pg_toast
  require_primary_key: true
  
file_registry:
  schema: cdc_registry  # Excluded from replication
  enabled: true
  cleanup_after_days: 7  # Auto-cleanup old entries
  
reload_coordination:
  marker_prefix: "CDC_RELOAD:"
  delta_strategy: discard  # During reload, ignore streaming changes
  use_csv_for_exports: true  # CSV is faster for full reloads
  
monitoring:
  metrics_port: 9090
  health_port: 8080
```


## Schema YAML Format

### Example schema.yml for Full Reload

```yaml
table:
  schema: public
  name: users
  row_count: 250000
  
columns:
  - name: id
    type: bigint
    nullable: false
    primary_key: true
    
  - name: email
    type: varchar
    length: 255
    nullable: false
    unique: true
    
  - name: name
    type: varchar
    length: 100
    nullable: true
    
  - name: created_at
    type: timestamp
    nullable: false
    default: CURRENT_TIMESTAMP
    
  - name: updated_at
    type: timestamp
    nullable: false
    
  - name: is_active
    type: boolean
    nullable: false
    default: true
    
indexes:
  - name: idx_users_email
    columns: [email]
    unique: true
    
  - name: idx_users_created_at
    columns: [created_at]
    
constraints:
  - name: pk_users
    type: primary_key
    columns: [id]
    
  - name: uk_users_email
    type: unique
    columns: [email]
    
metadata:
  exported_at: "2025-01-15T10:30:00Z"
```

## Monitoring for ETL Operations

### Key Metrics

```
File Organization Metrics:
- tables_monitored_count
- folders_created_per_hour
- files_per_folder_avg
- folder_size_bytes_avg

Compression Metrics:
- compression_ratio_by_type (CSV for all files)
- compression_duration_seconds
- cpu_usage_during_compression

ETL Pipeline Metrics:
- streaming_files_created_per_hour
- full_reload_operations_count
- schema_files_created_count
- oldest_unprocessed_folder_age

Per-Table Metrics:
- {table}_last_streaming_timestamp
- {table}_last_full_reload_timestamp
- {table}_total_folders_count
- {table}_average_batch_size_mb
```

### Health Dashboard

```
┌─────────────────────────────────────────────────────┐
│              CDC ETL File Manager                    │
├─────────────────────────────────────────────────────┤
│ Status: ● HEALTHY                                    │
│                                                      │
│ CURRENT BATCH                                       │
│ Timestamp:     2025-01-15T10:05:00                 │
│ Tables:        12 active                           │
│ Duration:      3m 42s / 5m                         │
│                                                      │
│ RECENT FILES                                        │
│ public.users/2025-01-15T10:00:00/                  │
│   └── streaming.csv.gz (2.4MB, 12K rows)        │
│ public.orders/2025-01-15T10:00:00/                 │
│   └── streaming.csv.gz (5.1MB, 34K rows)        │
│                                                      │
│ ACTIVE RELOAD                                       │
│ public.customers/2025-01-15T10:03:00/              │
│   ├── schema.yml (2KB)                             │
│   └── full_reload.csv.gz (45MB, 250K rows)        │
│                                                      │
│ STORAGE                                             │
│ Total Folders:   3,456                             │
│ Total Files:     10,234                            │
│ Disk Usage:      423GB / 1TB                       │
│ Compression:     8.7:1 average                     │
└─────────────────────────────────────────────────────┘
```

## Implementation Priorities

### Phase 1: Basic File Output
- Simple folder structure creation
- Basic gzip compression
- Database registry integration

### Phase 2: Full Reload Support
- CSV format for full exports
- Schema.yml generation
- DDL extraction logic
- File type differentiation

### Phase 3: File Registry
- Database schema setup
- Registration after file write
- Basic query interface
- ETL status tracking

### Phase 4: Compression & Optimization
- Configurable compression levels
- Checksum calculation
- Atomic file operations
- Performance tuning

### Phase 5: Production Features
- Kubernetes deployment
- Monitoring metrics
- Health checks
- Graceful shutdown

### Phase 6: ETL Integration
- Downstream process examples
- Snowflake ingestion patterns
- Archive and cleanup
- Operational tooling

## Kubernetes Startup Flow and Initialization

### Startup Decision Tree

```
CDC Tool Kubernetes Pod Startup
    │
    ▼
Connect to PostgreSQL
    │
    ▼
Check for Replication Slot: 'cdc_egress_slot'
    │
    ├─[Slot EXISTS]──────────────────────┐
    │                                     │
    ▼                                     ▼
[SLOT NOT FOUND]                    [SLOT FOUND]
Initial Setup Mode                   Resume Streaming Mode
    │                                     │
    ▼                                     ▼
Create Replication Slot              Connect to Existing Slot
    │                                     │
    ▼                                     ▼
Initialize Registry Tables           Check Registry State
    │                                     │
    ▼                                     ▼
Trigger Full Reload (All Tables)    Resume from Last LSN
    │                                     │
    ▼                                     ▼
Parallel Export Process              Continue Streaming
```

### Initial Setup Mode (No Replication Slot)

```
Initial Setup Flow
    │
    ▼
Step 1: Create Infrastructure
    │
    ├── Create replication slot:
    │   SELECT pg_create_logical_replication_slot(
    │       'cdc_egress_slot', 'pgoutput'
    │   );
    │
    ├── Create registry schema:
    │   CREATE SCHEMA IF NOT EXISTS cdc_registry;
    │
    ├── Create registry tables:
    │   - cdc_registry.file_log
    │   - cdc_registry.table_state
    │   - cdc_registry.reload_operations
    │
    └── Create DDL capture trigger
    │
    ▼
Step 2: Inventory Tables
    │
    ├── Query all tables in target schemas:
    │   SELECT table_schema, table_name, 
    │          pg_relation_size(c.oid) as table_size
    │   FROM information_schema.tables t
    │   JOIN pg_class c ON c.relname = t.table_name
    │   WHERE table_schema IN ('public', 'analytics')
    │   ORDER BY table_size ASC  -- Small tables first
    │
    └── Initialize table states:
        INSERT INTO cdc_registry.table_state
        (table_name, current_mode, updated_at)
        VALUES 
        ('public.users', 'pending_reload', NOW()),
        ('public.orders', 'pending_reload', NOW()),
        ...
    │
    ▼
Step 3: Parallel Table Export
    │
    ├── Launch export workers (configurable pool size)
    ├── Assign tables to workers (smallest first)
    └── Each worker executes independently:
        │
        ├── Mark START for table:
        │   COMMENT ON TABLE <table> IS 
        │   'CDC_RELOAD: {"action":"EXPORT_START"...}'
        │
        ├── Export table data:
        │   COPY <table> TO STDOUT WITH CSV HEADER
        │
        ├── Write files:
        │   - schema.yml
        │   - full_reload.csv.gz
        │
        ├── Mark END for table:
        │   COMMENT ON TABLE <table> IS 
        │   'CDC_RELOAD: {"action":"EXPORT_END"...}'
        │
        └── Transition to streaming:
            UPDATE cdc_registry.table_state
            SET current_mode = 'streaming'
            WHERE table_name = '<table>'
    │
    ▼
Step 4: Progressive Streaming Transition
    │
    ├── As each table completes export:
    │   └── Start streaming CDC for that table
    │
    ├── Monitor export progress:
    │   SELECT table_name, current_mode,
    │          COUNT(*) OVER() as total_tables,
    │          SUM(CASE WHEN current_mode = 'streaming' 
    │              THEN 1 ELSE 0 END) OVER() as completed
    │   FROM cdc_registry.table_state
    │
    └── When all tables complete:
        └── System fully in streaming mode
```

### Resume Streaming Mode (Replication Slot Exists)

```
Resume Streaming Flow
    │
    ▼
Step 1: Validate State
    │
    ├── Connect to replication slot:
    │   START_REPLICATION SLOT cdc_egress_slot 
    │   LOGICAL <last_confirmed_lsn>
    │
    ├── Check registry health:
    │   SELECT COUNT(*) FROM cdc_registry.table_state
    │   WHERE current_mode IN ('streaming', 'reloading')
    │
    └── Verify file system access:
        - Check base path exists
        - Verify write permissions
    │
    ▼
Step 2: Recovery Check
    │
    ├── Check for incomplete reloads:
    │   SELECT * FROM cdc_registry.reload_operations
    │   WHERE status = 'active'
    │
    ├── For each incomplete reload:
    │   ├── Check for END marker in WAL
    │   ├── If found: Complete the reload
    │   └── If not found: 
    │       ├── Check export files exist
    │       ├── Validate checksums
    │       └── Decide: resume or restart
    │
    └── Check for partial batches:
        SELECT * FROM cdc_registry.file_log
        WHERE created_at > NOW() - INTERVAL '1 hour'
        ORDER BY created_at DESC LIMIT 1
    │
    ▼
Step 3: Resume Operations
    │
    ├── Get last confirmed LSN:
    │   SELECT MAX(end_lsn) as last_lsn
    │   FROM cdc_registry.file_log
    │
    ├── Start consuming from WAL:
    │   - Begin from last_lsn
    │   - Process messages into batches
    │   - Respect table modes (streaming/reloading)
    │
    └── Continue normal batch processing:
        - 5-minute intervals
        - Write files per table
        - Update registry
```

### Parallel Export Strategy

```
Parallel Export Optimization
    │
    ▼
Worker Pool Configuration:
    │
    ├── Pool Size: min(table_count, max_workers)
    │   - Default: 4 workers
    │   - Configurable via environment
    │
    ├── Table Assignment Algorithm:
    │   1. Sort tables by size (smallest first)
    │   2. Assign to available workers
    │   3. Track progress per worker
    │
    └── Benefits:
        - Small tables complete quickly
        - Start streaming sooner
        - Better resource utilization
    │
    ▼
Example Timeline (4 workers, 10 tables):
    
    Worker 1: users (5GB)      ████████████████████
    Worker 2: sessions (100MB) ██
              products (200MB)   ███
              categories (50MB)   █
    Worker 3: orders (3GB)     ████████████
    Worker 4: events (8GB)     ██████████████████████████
    
    Time:     0m────────10m────────20m────────30m────────40m
    
    Streaming starts:
    - sessions:    2m
    - categories:  5m
    - products:    8m
    - orders:     15m
    - users:      20m
    - events:     40m
```

### Kubernetes Deployment Configuration

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cdc-egress-tool
spec:
  serviceName: cdc-egress
  replicas: 1  # Must be 1 for single replication slot
  template:
    spec:
      containers:
      - name: cdc-egress
        image: cdc-egress:latest
        env:
        - name: STARTUP_MODE
          value: "AUTO"  # AUTO, FORCE_RELOAD, or STREAMING_ONLY
        - name: MAX_EXPORT_WORKERS
          value: "4"
        - name: EXPORT_BATCH_SIZE
          value: "10000"
        - name: STREAMING_BATCH_INTERVAL
          value: "300"  # 5 minutes
        volumeMounts:
        - name: data-volume
          mountPath: /data
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
  volumeClaimTemplates:
  - metadata:
      name: data-volume
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi
```

### Health and Readiness Checks

```
Health Check (/health):
    │
    ├── Database connectivity
    ├── Replication slot active
    ├── File system writable
    └── No critical errors in last 5 min

Readiness Check (/ready):
    │
    ├── All startup tasks complete
    ├── At least one table in streaming mode
    ├── Registry tables accessible
    └── WAL consumer running
```

### Graceful Shutdown

```
Shutdown Sequence:
    │
    ├── Receive SIGTERM
    ├── Stop accepting new batches
    ├── Complete current batch
    ├── Write final files
    ├── Update registry
    ├── Flush LSN position
    ├── Close replication connection
    └── Exit with status 0
```

## PostgreSQL Replication Setup

### DDL Capture Configuration

PostgreSQL logical replication does not natively capture DDL changes in the WAL. To capture DDL events, we must install an event trigger that logs DDL commands as DML operations that can be replicated.

```sql
-- Create table to capture DDL events (this gets replicated)
CREATE TABLE public.ddl_history (
    id SERIAL PRIMARY KEY,
    event_time TIMESTAMP DEFAULT NOW(),
    ddl_tag TEXT,
    object_type TEXT,
    schema_name TEXT,
    object_name TEXT,
    object_identity TEXT,
    command_tag TEXT,
    ddl_command TEXT
);

-- Create event trigger function (based on AWS DMS approach)
CREATE OR REPLACE FUNCTION capture_ddl_commands()
RETURNS event_trigger AS $$
DECLARE
    cmd RECORD;
BEGIN
    FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
    LOOP
        -- Only capture DDL for user schemas, skip system schemas
        IF cmd.schema_name NOT IN ('pg_catalog', 'information_schema', 'cdc_registry') 
           OR cmd.schema_name IS NULL THEN
            INSERT INTO public.ddl_history (
                ddl_tag,
                object_type,
                schema_name,
                object_name,
                object_identity,
                command_tag,
                ddl_command
            ) VALUES (
                TG_TAG,
                cmd.object_type,
                cmd.schema_name,
                cmd.object_name,
                cmd.object_identity,
                cmd.command_tag,
                current_query()
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create database-wide event trigger (captures all DDL)
CREATE EVENT TRIGGER capture_ddl_trigger
ON ddl_command_end
EXECUTE FUNCTION capture_ddl_commands();

-- Note: This trigger runs at the database level and captures ALL DDL
-- The CDC tool will see these as regular INSERT operations in ddl_history table
```

### Publication Configuration

To prevent circular dependencies and avoid replicating CDC metadata, the publication must exclude the registry schema:

```sql
-- Create the CDC registry schema (not replicated)
CREATE SCHEMA IF NOT EXISTS cdc_registry;

-- Create publication including the DDL history table
CREATE PUBLICATION cdc_publication 
FOR ALL TABLES IN SCHEMA public, analytics
WITH (publish = 'insert,update,delete');

-- Or explicitly include tables plus DDL history
CREATE PUBLICATION cdc_publication FOR TABLE
    public.users,
    public.orders,
    public.products,
    public.ddl_history,  -- Important: Include DDL history table
    analytics.events;

-- Create replication slot
SELECT pg_create_logical_replication_slot('cdc_egress_slot', 'pgoutput');

-- Grant necessary permissions
GRANT USAGE ON SCHEMA cdc_registry TO cdc_user;
GRANT ALL ON ALL TABLES IN SCHEMA cdc_registry TO cdc_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA cdc_registry TO cdc_user;
```

### DDL Processing in CDC Tool

When the CDC tool encounters INSERT operations on the `ddl_history` table:

1. **Detection**: Identify INSERT to `public.ddl_history`
2. **Extraction**: Parse the DDL command and affected object
3. **File Writing**: Write DDL to separate `ddl.txt` file in batch folder
4. **Registry Update**: Mark batch as containing DDL (`has_ddl = TRUE`)

```
Example DDL File Structure:
/data/public.users/2025-01-15T10-05-00/
├── streaming.csv.gz     # Data changes
└── ddl.txt              # DDL commands from this batch
```

### Example DDL File Content

```sql
-- ddl.txt
-- Batch: 2025-01-15T10:05:00
-- Table: public.users

-- [2025-01-15 10:06:32] ALTER TABLE
ALTER TABLE public.users ADD COLUMN last_login TIMESTAMP;

-- [2025-01-15 10:08:15] CREATE INDEX  
CREATE INDEX idx_users_last_login ON public.users(last_login);

-- End of DDL for batch
```

### DDL Handling Strategy

1. **DDL Detection in WAL Stream**:
   - Monitor for INSERTs to `public.ddl_history` table
   - Extract DDL command and metadata from the INSERT payload
   - Associate DDL with affected table based on `object_identity`

2. **File Organization**:
   - DDL changes written to separate `ddl.txt` file
   - One DDL file per table per batch (if DDL exists)
   - Plain text format for easy downstream processing

3. **Downstream Processing**:
   - ETL processes must apply DDL before processing data changes
   - Schema evolution tracked through DDL files
   - DDL files provide audit trail of schema changes