# PostgreSQL COPY Protocol Implementation

This document describes the high-performance COPY protocol implementation for batch inserts in the LLM Observatory storage layer.

## Overview

The COPY protocol is PostgreSQL's native bulk data loading mechanism, offering 10-100x performance improvements over standard INSERT statements for large batches.

### Performance Comparison

| Method | Throughput | Use Case |
|--------|-----------|----------|
| Standard INSERT | ~5,000-10,000 rows/sec | Small batches, complex logic |
| INSERT with QueryBuilder | ~10,000-20,000 rows/sec | Medium batches |
| **COPY Binary Protocol** | **50,000-100,000 rows/sec** | **Large batches, high throughput** |

## Architecture

### Two Implementation Approaches

1. **INSERT (Default)**: Uses sqlx QueryBuilder for batch INSERT statements
   - Pros: Simpler, works with ON CONFLICT clauses, easier to debug
   - Cons: Lower throughput for large batches
   - Best for: < 1,000 rows per batch, need upsert logic

2. **COPY Protocol**: Uses tokio-postgres binary COPY
   - Pros: 10-100x faster, minimal overhead, binary format
   - Cons: No ON CONFLICT support, requires separate connection
   - Best for: > 1,000 rows per batch, append-only workloads

### Design Decision: Hybrid Approach

We use **tokio-postgres alongside sqlx** rather than choosing one or the other:

- **sqlx**: Used for queries, connection pooling, and standard writes
- **tokio-postgres**: Used only for COPY operations via `StoragePool::get_tokio_postgres_client()`

This gives us:
- Best-in-class performance for bulk inserts
- Full sqlx ecosystem for everything else
- Minimal additional complexity

## Usage

### Basic COPY Usage

```rust
use llm_observatory_storage::{
    StoragePool, StorageConfig,
    models::Trace,
    writers::CopyWriter,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Create storage pool
    let config = StorageConfig::from_env()?;
    let pool = StoragePool::new(config).await?;

    // Generate or collect traces
    let traces = vec![
        Trace::new("trace_1".to_string(), "my-service".to_string(), Utc::now()),
        // ... more traces
    ];

    // Get a tokio-postgres client for COPY
    let (client, _handle) = pool.get_tokio_postgres_client().await?;

    // Write using COPY protocol (much faster for large batches)
    let rows = CopyWriter::write_traces(&client, traces).await?;
    println!("Wrote {} traces", rows);

    Ok(())
}
```

### Configurable Write Method

Writers can be configured to use either INSERT or COPY:

```rust
use llm_observatory_storage::writers::{TraceWriter, WriterConfig, WriteMethod};

// Configure writer to use COPY
let config = WriterConfig {
    batch_size: 10000,
    write_method: WriteMethod::Copy,
    ..Default::default()
};

let writer = TraceWriter::with_config(pool.clone(), config);

// Writes will use COPY protocol when flush() is called
writer.write_traces(traces).await?;
writer.flush().await?; // Uses COPY internally
```

## Implementation Details

### How COPY Works

1. **Connection**: Establish a tokio-postgres client
2. **COPY Statement**: Send `COPY table_name FROM STDIN BINARY`
3. **Binary Writer**: Create `BinaryCopyInWriter` with column types
4. **Stream Data**: Write rows in PostgreSQL binary format
5. **Finish**: Complete the COPY transaction

### Binary Format

PostgreSQL's binary format is more efficient than text:
- No escaping/parsing overhead
- Native type representation
- Compact encoding
- Direct memory mapping

### Type Mapping

| Rust Type | PostgreSQL Type | Notes |
|-----------|----------------|-------|
| `Uuid` | `UUID` | Native UUID type |
| `String` | `TEXT` | UTF-8 text |
| `DateTime<Utc>` | `TIMESTAMPTZ` | Timezone-aware |
| `serde_json::Value` | `JSONB` | Binary JSON |
| `i32` | `INT4` | 32-bit integer |
| `i64` | `INT8` | 64-bit integer |
| `f64` | `FLOAT8` | 64-bit float |
| `Option<T>` | Nullable column | NULL support |

## Performance Tuning

### Batch Size Recommendations

```rust
// For traces (complex JSON attributes)
WriterConfig {
    batch_size: 1000,  // Sweet spot: 1,000-5,000
    write_method: WriteMethod::Copy,
    ..Default::default()
}

// For spans (more frequent, smaller)
WriterConfig {
    batch_size: 5000,  // Sweet spot: 5,000-10,000
    write_method: WriteMethod::Copy,
    ..Default::default()
}

// For logs (highest volume)
WriterConfig {
    batch_size: 10000,  // Sweet spot: 10,000-50,000
    write_method: WriteMethod::Copy,
    ..Default::default()
}
```

### PostgreSQL Configuration

Optimize PostgreSQL for COPY operations:

```sql
-- Increase maintenance_work_mem for faster index builds
SET maintenance_work_mem = '1GB';

-- Disable autovacuum during bulk loads
ALTER TABLE traces SET (autovacuum_enabled = false);

-- Re-enable after load
ALTER TABLE traces SET (autovacuum_enabled = true);
VACUUM ANALYZE traces;
```

### Network Tuning

For remote PostgreSQL:
```sql
-- Increase max WAL size
SET wal_buffers = '16MB';
SET checkpoint_timeout = '15min';

-- Async commit for non-critical data
SET synchronous_commit = 'off';  -- Trade durability for speed
```

## Benchmarking

### Running Benchmarks

```bash
# Set up test database
createdb llm_observatory_bench
export DATABASE_URL="postgres://postgres:password@localhost/llm_observatory_bench"

# Run migrations (create tables)
sqlx migrate run

# Run benchmarks
cargo bench --bench copy_vs_insert

# View results
open target/criterion/report/index.html
```

### Expected Results

On a modern laptop with local PostgreSQL:

```
traces_insert/100      time: [12.5 ms]    (~8,000 rows/sec)
traces_insert/1000     time: [95.2 ms]    (~10,500 rows/sec)
traces_insert/5000     time: [485 ms]     (~10,300 rows/sec)

traces_copy/100        time: [3.2 ms]     (~31,000 rows/sec)
traces_copy/1000       time: [18.5 ms]    (~54,000 rows/sec)
traces_copy/5000       time: [82.1 ms]    (~60,900 rows/sec)
traces_copy/10000      time: [155 ms]     (~64,500 rows/sec)

Speedup: 4-6x for typical workloads
```

## Limitations and Considerations

### When NOT to Use COPY

1. **Need ON CONFLICT**: COPY doesn't support upserts
   - Solution: Use INSERT with QueryBuilder
   - Or: Pre-filter duplicates, then COPY

2. **Small Batches**: Overhead not worth it for < 100 rows
   - Solution: Use standard INSERT

3. **Complex Business Logic**: Need per-row validation
   - Solution: Validate first, then COPY

### Handling Duplicates

COPY fails on constraint violations. Two approaches:

#### Approach 1: Pre-filter (Recommended)
```rust
// Query existing IDs
let existing_ids: HashSet<String> = sqlx::query_scalar(
    "SELECT trace_id FROM traces WHERE trace_id = ANY($1)"
)
.bind(&trace_ids)
.fetch_all(pool.postgres())
.await?
.into_iter()
.collect();

// Filter out duplicates
let new_traces: Vec<_> = traces
    .into_iter()
    .filter(|t| !existing_ids.contains(&t.trace_id))
    .collect();

// COPY only new traces
CopyWriter::write_traces(&client, new_traces).await?;
```

#### Approach 2: Temporary Table
```rust
// COPY to temp table
let (client, _) = pool.get_tokio_postgres_client().await?;
client.execute("CREATE TEMP TABLE traces_temp (LIKE traces INCLUDING ALL)", &[]).await?;
CopyWriter::write_traces_to_table(&client, "traces_temp", traces).await?;

// INSERT from temp with ON CONFLICT
client.execute(
    "INSERT INTO traces SELECT * FROM traces_temp
     ON CONFLICT (trace_id) DO NOTHING",
    &[]
).await?;
```

### Error Handling

COPY is all-or-nothing:
- Single bad row fails entire batch
- Validate data before COPY
- Log failed batches for retry

```rust
match CopyWriter::write_traces(&client, traces).await {
    Ok(count) => {
        tracing::info!("Wrote {} traces", count);
    }
    Err(e) => {
        tracing::error!("COPY failed: {}. Falling back to INSERT", e);
        // Fallback to INSERT with better error handling
        for trace in traces {
            if let Err(e) = insert_single_trace(&trace).await {
                tracing::error!("Failed to insert trace {}: {}", trace.id, e);
            }
        }
    }
}
```

## Migration Strategy

### Gradual Adoption

1. **Start with logs**: Highest volume, simplest schema
2. **Add metrics**: Next highest volume
3. **Add traces**: Most complex, but highest value

### Feature Flag Pattern

```rust
impl TraceWriter {
    pub async fn flush(&self) -> StorageResult<()> {
        let use_copy = self.config.write_method == WriteMethod::Copy
            && self.buffer_len() > 1000;  // Only for large batches

        if use_copy {
            self.flush_with_copy().await
        } else {
            self.flush_with_insert().await
        }
    }
}
```

## Monitoring

### Key Metrics

```rust
// Track COPY performance
#[derive(Debug, Clone)]
pub struct CopyStats {
    pub total_rows: u64,
    pub total_batches: u64,
    pub total_duration: Duration,
    pub avg_throughput: f64,  // rows/sec
    pub p50_batch_time: Duration,
    pub p99_batch_time: Duration,
}
```

### Logging

```rust
tracing::info!(
    target: "storage::copy",
    rows = %rows_written,
    duration_ms = %elapsed.as_millis(),
    throughput = %(rows_written as f64 / elapsed.as_secs_f64()),
    "COPY completed"
);
```

## Future Enhancements

1. **Connection Pooling**: Pool of tokio-postgres clients for COPY
2. **Parallel COPY**: Split batches across multiple connections
3. **Compression**: Use COPY with GZIP for network efficiency
4. **Schema Evolution**: Handle column additions gracefully
5. **Partitioning**: COPY directly to partition tables

## References

- [PostgreSQL COPY Documentation](https://www.postgresql.org/docs/current/sql-copy.html)
- [tokio-postgres binary_copy](https://docs.rs/tokio-postgres/latest/tokio_postgres/binary_copy/)
- [PostgreSQL Binary Format](https://www.postgresql.org/docs/current/protocol-overview.html)

## See Also

- [Benchmark Results](./benches/copy_vs_insert.rs)
- [Writer Configuration](./src/writers/trace.rs)
- [COPY Implementation](./src/writers/copy.rs)
