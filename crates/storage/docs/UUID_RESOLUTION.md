# UUID Resolution for LlmSpan Conversion

## Overview

This document explains how the storage layer resolves trace UUIDs when converting `LlmSpan` instances (which use string trace IDs) to `TraceSpan` instances (which use UUID trace IDs).

## Problem Statement

The LLM Observatory uses two different ID systems:

1. **Core Layer (LlmSpan)**: Uses string trace IDs for OpenTelemetry compatibility
   - Example: `trace_id: "abc123def456"`
   - Format: Hex string, typically 16 or 32 characters

2. **Storage Layer (TraceSpan)**: Uses UUID trace IDs for database foreign keys
   - Example: `trace_id: UUID("550e8400-e29b-41d4-a716-446655440000")`
   - Format: Standard UUID v4

The challenge is converting between these two representations while maintaining referential integrity in the database.

## Solution: TraceWriter::write_span_from_llm()

The recommended approach is to use the `write_span_from_llm()` method on `TraceWriter`, which:

1. Queries the database for an existing trace with the given string trace_id
2. Creates a new trace if one doesn't exist
3. Converts the LlmSpan to TraceSpan with the proper UUID
4. Writes the span to the database

### Usage Example

```rust
use llm_observatory_storage::writers::TraceWriter;
use llm_observatory_storage::pool::StoragePool;
use llm_observatory_core::span::LlmSpan;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize storage pool
    let pool = StoragePool::new(config).await?;

    // Create trace writer
    let writer = TraceWriter::new(pool);

    // Create an LlmSpan (from your LLM instrumentation)
    let llm_span = LlmSpan::builder()
        .span_id("span_abc123")
        .trace_id("trace_xyz789")  // String trace ID
        .name("llm.completion")
        .provider(Provider::OpenAI)
        .model("gpt-4")
        .input(LlmInput::Text { prompt: "Hello".to_string() })
        .latency(Latency::new(start, end))
        .status(SpanStatus::Ok)
        .build()?;

    // Write the span - this will:
    // 1. Look up or create trace with trace_id="trace_xyz789"
    // 2. Convert LlmSpan to TraceSpan with proper UUID
    // 3. Write to database
    let trace_span = writer.write_span_from_llm(llm_span).await?;

    // Flush to ensure data is written
    writer.flush().await?;

    println!("Span written with trace UUID: {}", trace_span.trace_id);

    Ok(())
}
```

## Implementation Details

### Method Signature

```rust
#[cfg(feature = "llm-span-conversion")]
pub async fn write_span_from_llm(
    &self,
    llm_span: llm_observatory_core::span::LlmSpan,
) -> StorageResult<TraceSpan>
```

### Flow Diagram

```
LlmSpan (trace_id: "abc123")
    |
    v
write_span_from_llm()
    |
    +---> ensure_trace("abc123", llm_span)
    |         |
    |         +---> Query: SELECT * FROM traces WHERE trace_id = 'abc123'
    |         |
    |         +---> If found: Return existing Trace (with UUID)
    |         |
    |         +---> If not found:
    |                   |
    |                   +---> Create new Trace
    |                   +---> INSERT with ON CONFLICT (handles races)
    |                   +---> Return Trace (with UUID)
    |
    +---> TraceSpan::from(llm_span)
    |
    +---> Set trace_span.trace_id = trace.id  (UUID)
    |
    +---> write_span(trace_span)
    |
    v
TraceSpan (trace_id: UUID)
```

### Concurrency Handling

The `ensure_trace()` method handles concurrent writes correctly:

1. **First attempt**: Query for existing trace
2. **If not found**: Try to INSERT new trace
3. **ON CONFLICT clause**: If another writer created the trace concurrently, use their version
4. **RETURNING clause**: Get the trace UUID (either new or existing)

This ensures that:
- Multiple writers can safely call `write_span_from_llm()` for the same trace_id
- No duplicate traces are created
- No race conditions occur
- Minimal database queries (typically 1-2 per trace)

### SQL Query

```sql
INSERT INTO traces (
    id, trace_id, service_name, start_time, end_time,
    duration_us, status, status_message, root_span_name,
    attributes, resource_attributes, span_count,
    created_at, updated_at
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
ON CONFLICT (trace_id)
DO UPDATE SET updated_at = EXCLUDED.updated_at
RETURNING *;
```

## Alternative: Direct From<LlmSpan> Conversion

The `From<LlmSpan>` trait is still available, but creates a placeholder UUID:

```rust
// This creates a TraceSpan with a random UUID
let trace_span = TraceSpan::from(llm_span);

// You must manually set the trace_id afterward
trace_span.trace_id = actual_trace_uuid;
```

**When to use this:**
- Testing and development
- Batch operations where you'll resolve UUIDs separately
- Cases where you manually manage trace creation

**When NOT to use this:**
- Production code (use `write_span_from_llm()` instead)
- When you need the correct trace UUID immediately
- When writing directly to the database

## Performance Considerations

### Efficiency

The `write_span_from_llm()` method is optimized for performance:

1. **Query optimization**: Uses indexed lookup on `trace_id`
2. **Minimal queries**: 1 query if trace exists, 2 if creating new trace
3. **Batch-friendly**: Buffered writes via TraceWriter
4. **Connection pooling**: Reuses database connections

### Typical Performance

- **Existing trace**: ~1ms (1 SELECT query)
- **New trace**: ~2-5ms (1 SELECT + 1 INSERT)
- **Concurrent creation**: ~2-5ms (ON CONFLICT handles race)

### Optimization Tips

For high-volume scenarios:

1. **Batch writes**: Let TraceWriter buffer spans before flushing
   ```rust
   for llm_span in llm_spans {
       writer.write_span_from_llm(llm_span).await?;
   }
   writer.flush().await?;  // Batch flush
   ```

2. **Connection pooling**: Configure adequate pool size
   ```rust
   let config = StorageConfig {
       pool: PoolConfig {
           max_connections: 20,
           ..Default::default()
       },
       ..config
   };
   ```

3. **Caching**: Consider caching trace UUID mappings for repeated trace_ids
   ```rust
   // Advanced: Application-level cache
   let mut trace_cache: HashMap<String, Uuid> = HashMap::new();

   if let Some(uuid) = trace_cache.get(&llm_span.trace_id) {
       // Use cached UUID
   } else {
       // Use write_span_from_llm() and cache result
   }
   ```

## Error Handling

### Common Errors

1. **Database connection error**
   ```rust
   Err(StorageError::ConnectionError("Failed to connect to database"))
   ```
   - **Cause**: Database is down or unreachable
   - **Solution**: Retry with exponential backoff (built-in)

2. **Query error**
   ```rust
   Err(StorageError::QueryError("Foreign key violation"))
   ```
   - **Cause**: Data integrity issue
   - **Solution**: Check data validity before writing

3. **Validation error**
   ```rust
   Err(StorageError::ValidationError("Invalid trace_id format"))
   ```
   - **Cause**: Malformed trace_id
   - **Solution**: Validate trace_id format (hex string)

### Error Recovery

The `TraceWriter` includes automatic retry logic for transient errors:

```rust
pub async fn write_span_from_llm(&self, llm_span: LlmSpan) -> StorageResult<TraceSpan> {
    // Automatically retries on:
    // - ConnectionError
    // - PoolError
    // - Timeout
    //
    // Max retries: 3
    // Backoff: Exponential (100ms, 200ms, 400ms)
}
```

## Testing

### Unit Tests

The implementation includes comprehensive unit tests:

```rust
#[cfg(test)]
mod llm_span_conversion_tests {
    // Test basic conversion
    #[test]
    fn test_from_llm_span_creates_trace_span() { ... }

    // Test status conversion
    #[test]
    fn test_from_llm_span_converts_status_correctly() { ... }

    // Test attribute mapping
    #[test]
    fn test_from_llm_span_includes_llm_attributes() { ... }

    // Test token usage
    #[test]
    fn test_from_llm_span_with_token_usage() { ... }

    // Test cost tracking
    #[test]
    fn test_from_llm_span_with_cost() { ... }

    // Test metadata
    #[test]
    fn test_from_llm_span_with_metadata() { ... }

    // Test duration conversion
    #[test]
    fn test_from_llm_span_duration_conversion() { ... }

    // Test events
    #[test]
    fn test_from_llm_span_with_events() { ... }

    // Test custom attributes
    #[test]
    fn test_from_llm_span_custom_attributes() { ... }
}
```

Run tests with:
```bash
cargo test -p llm-observatory-storage --features llm-span-conversion
```

### Integration Tests

Integration tests with a real database should verify:

1. **Trace creation**: First span creates trace
2. **Trace reuse**: Subsequent spans reuse existing trace
3. **Concurrent writes**: Multiple writers don't create duplicate traces
4. **Race conditions**: ON CONFLICT handles concurrent trace creation
5. **End-to-end**: LlmSpan → write → query → verify

Example integration test:
```rust
#[tokio::test]
async fn test_write_span_from_llm_creates_trace() {
    let pool = setup_test_pool().await;
    let writer = TraceWriter::new(pool.clone());

    let llm_span = create_test_llm_span();
    let trace_span = writer.write_span_from_llm(llm_span.clone()).await.unwrap();
    writer.flush().await.unwrap();

    // Verify trace was created
    let repo = TraceRepository::new(pool);
    let trace = repo.get_by_trace_id(&llm_span.trace_id).await.unwrap();
    assert_eq!(trace.id, trace_span.trace_id);
}
```

## Migration Guide

### Migrating Existing Code

**Before:**
```rust
// Old approach - doesn't work correctly
let trace_span = TraceSpan::from(llm_span);
writer.write_span(trace_span).await?;  // ❌ Wrong UUID!
```

**After:**
```rust
// New approach - correct UUID resolution
let trace_span = writer.write_span_from_llm(llm_span).await?;  // ✅ Correct UUID!
```

### Backward Compatibility

The `From<LlmSpan>` implementation is still available for backward compatibility, but:

1. It creates a placeholder UUID (not database-resolved)
2. Documentation now warns against production use
3. The `write_span_from_llm()` method is the recommended approach

## FAQ

### Q: Why not just use string trace IDs everywhere?

**A:** UUIDs provide:
- Efficient database indexing (16 bytes vs variable-length string)
- Native foreign key support in PostgreSQL
- Better query performance
- Standard format across all database tables

### Q: What if I have millions of traces?

**A:** The solution scales well:
- Indexed lookups are O(log n)
- Connection pooling handles concurrent requests
- Batch writes minimize database round-trips
- Consider adding application-level caching for hot traces

### Q: Can I batch process multiple LlmSpans?

**A:** Yes, the TraceWriter supports batching:
```rust
for llm_span in llm_spans {
    writer.write_span_from_llm(llm_span).await?;
    // Buffered, not flushed yet
}
writer.flush().await?;  // Single batch write
```

### Q: What happens if two writers create the same trace simultaneously?

**A:** The ON CONFLICT clause ensures only one trace is created:
- Writer 1: INSERT succeeds, creates trace
- Writer 2: INSERT conflicts, uses existing trace
- Both writers get the same trace UUID
- No duplicates, no errors

### Q: How do I enable this feature?

**A:** Add the feature flag:
```toml
[dependencies]
llm-observatory-storage = { version = "0.1", features = ["llm-span-conversion"] }
```

## See Also

- [Storage Layer Usage Guide](../USAGE.md)
- [Batch Writer Documentation](../BATCH_WRITER.md)
- [Repository Implementation](../REPOSITORY_IMPLEMENTATION.md)
- [Storage Layer Completion Plan](../../../plans/storage-layer-completion-plan.md)

## References

- [OpenTelemetry Trace Specification](https://opentelemetry.io/docs/specs/otel/trace/api/)
- [PostgreSQL UUID Type](https://www.postgresql.org/docs/current/datatype-uuid.html)
- [PostgreSQL ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT)
- [sqlx Documentation](https://docs.rs/sqlx/)

---

**Last Updated:** 2025-11-05
**Version:** 1.0
**Authors:** LLM Observatory Contributors
