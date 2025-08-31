# PostgreSQL CDC Egress Tool - Rust Implementation Plan

## Overview
This document outlines the complete implementation plan for the PostgreSQL CDC (Change Data Capture) egress tool in Rust, based on the architecture defined in ARCHITECTURE.md.

## Core Module Structure

```
src/
├── main.rs                     # Entry point, CLI args, startup logic
├── config.rs                   # Configuration management
├── lib.rs                      # Library root
│
├── connection/
│   ├── mod.rs                  # Connection module
│   ├── postgres.rs             # PostgreSQL connection management
│   ├── replication.rs          # Replication slot handling
│   └── pool.rs                 # Connection pooling for parallel exports
│
├── replication/
│   ├── mod.rs                  # Replication module
│   ├── wal_consumer.rs         # WAL stream consumer
│   ├── decoder.rs              # pgoutput protocol decoder
│   ├── message.rs              # WAL message types
│   └── lsn.rs                  # LSN management and tracking
│
├── batch/
│   ├── mod.rs                  # Batch processing module
│   ├── controller.rs           # Micro-batch controller (5-min intervals)
│   ├── buffer.rs               # In-memory change buffering
│   ├── aggregator.rs           # Table-based change aggregation
│   └── scheduler.rs            # Batch timing and triggers
│
├── reload/
│   ├── mod.rs                  # Table reload module
│   ├── coordinator.rs          # DDL comment coordination
│   ├── detector.rs             # START/END marker detection
│   ├── exporter.rs             # Parallel table export logic
│   └── state_machine.rs        # Reload state transitions
│
├── registry/
│   ├── mod.rs                  # Registry module
│   ├── file_log.rs             # File registry operations
│   ├── table_state.rs          # Table state management
│   ├── operations.rs           # Reload operation tracking
│   └── schema.rs               # Registry schema definitions
│
├── output/
│   ├── mod.rs                  # File output module
│   ├── writer.rs               # File writing logic
│   ├── csv_formatter.rs        # CSV formatting for data
│   ├── schema_generator.rs     # schema.yml generation
│   ├── ddl_writer.rs           # DDL file writer
│   └── compression.rs          # Gzip compression
│
├── startup/
│   ├── mod.rs                  # Startup module
│   ├── initializer.rs          # System initialization
│   ├── slot_checker.rs         # Replication slot detection
│   ├── recovery.rs             # Crash recovery logic
│   └── health.rs               # Health/readiness checks
│
├── models/
│   ├── mod.rs                  # Data models
│   ├── change.rs               # CDC change records
│   ├── table.rs                # Table metadata
│   ├── file.rs                 # File metadata
│   └── ddl.rs                  # DDL history model
│
└── utils/
    ├── mod.rs                  # Utilities
    ├── error.rs                # Error handling
    ├── metrics.rs              # Prometheus metrics
    └── shutdown.rs             # Graceful shutdown
```

## Dependencies (Cargo.toml)

```toml
[dependencies]
# PostgreSQL and replication
tokio-postgres = "0.7"
postgres-protocol = "0.6"  # For pgoutput decoding
deadpool-postgres = "0.11"  # Connection pooling

# Async runtime
tokio = { version = "1.35", features = ["full"] }
futures = "0.3"

# Data processing
csv = "1.3"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
serde_yaml = "0.9"
chrono = { version = "0.4", features = ["serde"] }

# Compression
flate2 = "1.0"  # Gzip compression

# Error handling
thiserror = "1.0"
anyhow = "1.0"

# Configuration
config = "0.13"
clap = { version = "4.4", features = ["derive"] }

# Observability
tracing = "0.1"
tracing-subscriber = "0.3"
prometheus = "0.13"

# Utilities
uuid = { version = "1.6", features = ["v4", "serde"] }
bytes = "1.5"
once_cell = "1.19"

[dev-dependencies]
testcontainers = "0.15"  # PostgreSQL containers for testing
proptest = "1.4"          # Property-based testing
criterion = "0.5"         # Benchmarking
```

## Core Data Types

### Change Model
```rust
// models/change.rs
pub enum ChangeType {
    Insert,
    Update,
    Delete,
    DDL,
}

pub struct Change {
    pub table_name: String,
    pub change_type: ChangeType,
    pub lsn: PgLsn,
    pub timestamp: DateTime<Utc>,
    pub data: serde_json::Value,
    pub old_data: Option<serde_json::Value>,  // For updates
}
```

### Table Model
```rust
// models/table.rs
pub struct TableMetadata {
    pub schema: String,
    pub name: String,
    pub columns: Vec<ColumnInfo>,
    pub primary_keys: Vec<String>,
}

pub enum TableMode {
    Streaming,
    Reloading,
    PendingReload,
}
```

### File Model
```rust
// models/file.rs
pub struct FileMetadata {
    pub table_name: String,
    pub batch_timestamp: DateTime<Utc>,
    pub file_path: PathBuf,
    pub file_type: FileType,
    pub end_lsn: PgLsn,
    pub row_count: i32,
    pub has_ddl: bool,
}

pub enum FileType {
    Streaming,
    FullReload,
    DDL,
}
```

### DDL Model
```rust
// models/ddl.rs
pub struct DdlEvent {
    pub event_time: DateTime<Utc>,
    pub object_type: String,
    pub schema_name: Option<String>,
    pub object_name: Option<String>,
    pub command: String,
}
```

## Key Component Implementations

### WAL Consumer
```rust
// replication/wal_consumer.rs
pub struct WalConsumer {
    connection: ReplicationConnection,
    decoder: PgOutputDecoder,
    batch_buffer: Arc<Mutex<BatchBuffer>>,
}

impl WalConsumer {
    pub async fn start_streaming(&mut self, start_lsn: PgLsn) -> Result<()> {
        // Connect to replication slot
        // Decode pgoutput messages
        // Buffer changes by table
        // Detect DDL comment markers
    }
}
```

### Batch Controller
```rust
// batch/controller.rs
pub struct BatchController {
    interval: Duration,
    max_size_bytes: usize,
    max_rows: usize,
    buffer: Arc<Mutex<BatchBuffer>>,
}

impl BatchController {
    pub async fn run(&self) -> Result<()> {
        // 5-minute timer loop
        // Flush batches on interval or size limits
        // Coordinate with file writers
    }
}
```

### Reload Coordinator
```rust
// reload/coordinator.rs
pub struct ReloadCoordinator {
    registry: Arc<Registry>,
    export_pool: ExportWorkerPool,
}

impl ReloadCoordinator {
    pub async fn handle_reload_marker(&self, marker: ReloadMarker) -> Result<()> {
        match marker.action {
            "EXPORT_START" => self.start_export(marker).await,
            "EXPORT_END" => self.complete_export(marker).await,
            _ => Ok(())
        }
    }
    
    pub async fn parallel_initial_export(&self, tables: Vec<TableInfo>) -> Result<()> {
        // Sort tables by size
        // Distribute to worker pool
        // Track progress
        // Transition to streaming as each completes
    }
}
```

### File Writer
```rust
// output/writer.rs
pub struct FileWriter {
    base_path: PathBuf,
    compressor: GzipCompressor,
}

impl FileWriter {
    pub async fn write_streaming_batch(&self, 
        table: &str, 
        timestamp: DateTime<Utc>,
        changes: Vec<Change>
    ) -> Result<FileMetadata> {
        // Create directory: /data/{table}/{timestamp}/
        // Write streaming.csv.gz
        // Handle DDL if present
        // Return metadata for registry
    }
    
    pub async fn write_full_reload(&self,
        table: &str,
        timestamp: DateTime<Utc>,
        schema: TableMetadata,
        data_stream: impl AsyncRead
    ) -> Result<FileMetadata> {
        // Write schema.yml
        // Stream data through CSV formatter and gzip
        // Write full_reload.csv.gz
    }
}
```

### File Registry
```rust
// registry/file_log.rs
pub struct FileRegistry {
    pool: Pool<Postgres>,
}

impl FileRegistry {
    pub async fn register_file(&self, metadata: FileMetadata) -> Result<()> {
        // Insert into cdc_registry.file_log
        // Update table_state if needed
    }
    
    pub async fn get_table_state(&self, table: &str) -> Result<TableState> {
        // Query cdc_registry.table_state
    }
    
    pub async fn update_table_mode(&self, table: &str, mode: TableMode) -> Result<()> {
        // Update streaming/reloading status
    }
}
```

## Testing Strategy

### Unit Tests
```
tests/unit/
├── replication/
│   ├── test_pgoutput_decoder.rs    # Test message decoding
│   ├── test_lsn_tracking.rs        # LSN comparison and management
│   └── test_wal_parsing.rs         # WAL message parsing
│
├── batch/
│   ├── test_buffer.rs              # Change buffering logic
│   ├── test_aggregation.rs         # Table-based aggregation
│   └── test_scheduler.rs           # Batch timing
│
├── reload/
│   ├── test_marker_detection.rs    # DDL comment parsing
│   ├── test_state_machine.rs       # State transitions
│   └── test_parallel_export.rs     # Worker pool distribution
│
├── output/
│   ├── test_csv_formatter.rs       # CSV generation
│   ├── test_schema_generator.rs    # schema.yml creation
│   └── test_compression.rs         # Gzip compression
│
└── registry/
    ├── test_file_log.rs            # Registry operations
    └── test_state_tracking.rs      # Table state changes
```

### Integration Tests
```
tests/integration/
├── test_startup_flow.rs            # Test slot detection and initialization
├── test_streaming_pipeline.rs      # End-to-end streaming
├── test_reload_coordination.rs     # Full reload with markers
├── test_crash_recovery.rs          # Recovery scenarios
├── test_parallel_exports.rs        # Multiple table exports
└── test_ddl_capture.rs            # DDL event processing
```

### Test Scenarios
1. **Fresh Start**: No replication slot → creates slot and triggers full reload
2. **Resume Streaming**: Existing slot → resumes from last LSN
3. **Reload Coordination**: DDL marker detection → proper state transitions
4. **Batch Processing**: 5-minute intervals and size limits
5. **Crash Recovery**: Recovery during export, streaming, or batch flush
6. **DDL Events**: Proper DDL file generation from ddl_history table
7. **Parallel Exports**: Multiple tables exporting concurrently

### Property-Based Tests
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_lsn_ordering(lsn1: u64, lsn2: u64) {
        // LSN comparison properties
    }
    
    #[test]
    fn test_batch_aggregation(changes: Vec<Change>) {
        // Aggregation maintains consistency
    }
}
```

### Performance Tests
```
benches/
├── bench_wal_decoding.rs          # pgoutput decoding performance
├── bench_csv_generation.rs        # CSV formatting speed
├── bench_compression.rs           # Compression throughput
└── bench_parallel_export.rs       # Multi-table export scaling
```

### End-to-End Test
```rust
#[tokio::test]
async fn test_complete_lifecycle() {
    // 1. Start PostgreSQL container
    // 2. Create tables and DDL trigger
    // 3. Start CDC tool (no slot exists)
    // 4. Verify slot creation
    // 5. Verify parallel exports start
    // 6. Insert data during export
    // 7. Complete exports
    // 8. Verify transition to streaming
    // 9. Make changes
    // 10. Wait for batch interval
    // 11. Verify CSV files created
    // 12. Trigger table reload
    // 13. Verify DDL markers
    // 14. Verify reload completion
    // 15. Verify registry consistency
}
```

### Test Infrastructure
```rust
// tests/fixtures/
├── postgres_container.rs          // Testcontainers setup
├── test_data.rs                  // Sample data generation
├── mock_replication.rs           // Mock WAL stream
└── test_config.rs                // Test configurations

// Test utilities
pub async fn setup_test_db() -> TestDatabase {
    // Create container
    // Apply schema
    // Create replication slot
    // Setup DDL trigger
}

pub fn generate_changes(count: usize) -> Vec<Change> {
    // Generate realistic CDC changes
}
```

## Implementation Phases

### Phase 1: Core Foundation (Week 1-2)
- [ ] Basic PostgreSQL connection and replication slot management
- [ ] pgoutput decoder for WAL messages  
- [ ] Simple file writing with CSV format
- [ ] Basic registry tables

### Phase 2: Batch Processing (Week 3)
- [ ] 5-minute batch controller
- [ ] Table-based change aggregation
- [ ] Gzip compression
- [ ] File registry updates

### Phase 3: Reload Coordination (Week 4-5)
- [ ] DDL comment marker detection
- [ ] Parallel export worker pool
- [ ] State machine for reload tracking
- [ ] Progressive streaming transition

### Phase 4: Production Features (Week 6)
- [ ] Kubernetes health/readiness endpoints
- [ ] Prometheus metrics
- [ ] Graceful shutdown
- [ ] Crash recovery

### Phase 5: Testing & Hardening (Week 7-8)
- [ ] Comprehensive test suite
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] Documentation

## Critical Success Factors

1. **Correctness**: No data loss, exactly-once semantics
2. **Performance**: Handle high-volume tables efficiently  
3. **Reliability**: Crash-safe with proper recovery
4. **Observability**: Clear metrics and logging
5. **Simplicity**: Clean file structure for downstream consumption

## Key Design Decisions

### Why Rust?
- Memory safety without garbage collection
- Excellent async/await support for I/O-heavy workloads
- Strong type system prevents many runtime errors
- Great performance for data processing

### Why CSV Format?
- Universal compatibility with data tools
- Faster parsing than JSON for large datasets
- Smaller file sizes when compressed
- Simple schema representation

### Why 5-Minute Batches?
- Predictable processing windows for downstream ETL
- Balance between latency and efficiency
- Reduces small file problem
- Aligns with typical data warehouse loading patterns

### Why DDL Comments for Coordination?
- Native PostgreSQL feature, no custom protocols
- Appears in WAL stream at exact LSN position
- Provides natural synchronization point
- Simple to implement and debug

## Monitoring & Observability

### Key Metrics
```
# Replication metrics
cdc_replication_lag_seconds
cdc_wal_position_bytes
cdc_slot_active

# Batch metrics
cdc_batch_duration_seconds
cdc_batch_size_bytes
cdc_batch_row_count
cdc_batches_processed_total

# File metrics
cdc_files_written_total
cdc_file_size_bytes
cdc_compression_ratio

# Table metrics
cdc_table_mode{table="..."} # streaming/reloading
cdc_table_last_batch_timestamp{table="..."}
cdc_table_pending_changes{table="..."}

# Error metrics
cdc_errors_total{type="..."}
cdc_recovery_attempts_total
```

### Logging Strategy
- Structured logging with tracing
- Correlation IDs for batch tracking
- Separate log levels per module
- JSON output for Kubernetes

## Security Considerations

1. **Connection Security**
   - Use SSL/TLS for PostgreSQL connections
   - Store passwords in Kubernetes secrets
   - Use service accounts for authentication

2. **File System Security**
   - Restrict file permissions (600 for files, 700 for directories)
   - Use volume encryption in Kubernetes
   - Implement file integrity checks

3. **Registry Security**
   - Separate schema with restricted access
   - No sensitive data in registry tables
   - Audit logging for registry modifications

## Performance Optimization

1. **Memory Management**
   - Stream processing for large tables
   - Bounded buffers for change aggregation
   - Lazy loading of table metadata

2. **I/O Optimization**
   - Async I/O throughout
   - Parallel file writes per table
   - Direct streaming to compressed files

3. **Database Optimization**
   - Connection pooling for registry operations
   - Batch registry inserts
   - Indexed queries on LSN and timestamps

## Future Enhancements

1. **Additional Output Formats**
   - Parquet for analytical workloads
   - Avro for schema evolution
   - Protocol buffers for efficiency

2. **Advanced Features**
   - Filtering and transformation rules
   - Dead letter queue for failed changes
   - Automatic schema migration handling

3. **Operational Improvements**
   - Web UI for monitoring
   - REST API for management
   - Automatic cleanup of old files

## References

- [PostgreSQL Logical Replication](https://www.postgresql.org/docs/current/logical-replication.html)
- [pgoutput Plugin](https://www.postgresql.org/docs/current/protocol-logical-replication.html)
- [Tokio Async Runtime](https://tokio.rs/)
- [CSV RFC 4180](https://datatracker.ietf.org/doc/html/rfc4180)