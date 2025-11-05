//! Example demonstrating the storage monitoring and metrics system.
//!
//! This example shows how to:
//! - Initialize metrics and health endpoints
//! - Use instrumented writers and repositories
//! - Update pool metrics periodically
//! - Access health and metrics endpoints
//!
//! Run with:
//! ```bash
//! cargo run --example monitoring_example
//! ```
//!
//! Then access:
//! - Health: http://localhost:9090/health
//! - Metrics: http://localhost:9090/metrics
//! - Liveness: http://localhost:9090/health/live
//! - Readiness: http://localhost:9090/health/ready

use llm_observatory_storage::{
    HealthServer, StorageConfig, StorageMetrics, StoragePool,
    models::{Trace, TraceSpan},
    repositories::InstrumentedTraceRepository,
    writers::InstrumentedTraceWriter,
};
use std::sync::Arc;
use tokio::time::{interval, Duration};
use chrono::Utc;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    println!("🚀 Starting LLM Observatory Storage Monitoring Example");
    println!();

    // Load configuration
    println!("📝 Loading configuration...");
    let config = StorageConfig::from_env()?;

    // Create storage pool
    println!("🔌 Connecting to database...");
    let pool = StoragePool::new(config).await?;
    println!("✅ Connected successfully");
    println!();

    // Initialize metrics
    println!("📊 Initializing metrics...");
    let metrics = Arc::new(StorageMetrics::new());
    println!("✅ Metrics initialized");
    println!();

    // Start health and metrics server
    println!("🏥 Starting health and metrics server on port 9090...");
    let health_server = HealthServer::new(pool.clone());
    tokio::spawn(async move {
        if let Err(e) = health_server.serve("0.0.0.0:9090").await {
            eprintln!("Health server error: {}", e);
        }
    });
    println!("✅ Health server started");
    println!();

    // Start periodic pool metrics updates
    let pool_clone = pool.clone();
    tokio::spawn(async move {
        let mut ticker = interval(Duration::from_secs(10));
        loop {
            ticker.tick().await;
            pool_clone.update_metrics();
        }
    });
    println!("📈 Started periodic pool metrics updates (every 10s)");
    println!();

    // Create instrumented writer
    println!("✍️  Creating instrumented trace writer...");
    let writer = InstrumentedTraceWriter::new(pool.clone(), metrics.clone());
    println!("✅ Writer created");
    println!();

    // Create instrumented repository
    println!("📖 Creating instrumented trace repository...");
    let repository = InstrumentedTraceRepository::new(pool.clone(), metrics.clone());
    println!("✅ Repository created");
    println!();

    // Wait a moment for server to start
    tokio::time::sleep(Duration::from_secs(1)).await;

    println!("════════════════════════════════════════════════════════");
    println!("📍 Health and Metrics Endpoints Available:");
    println!("   Health Check:      http://localhost:9090/health");
    println!("   Prometheus Metrics: http://localhost:9090/metrics");
    println!("   Liveness Probe:    http://localhost:9090/health/live");
    println!("   Readiness Probe:   http://localhost:9090/health/ready");
    println!("════════════════════════════════════════════════════════");
    println!();

    // Demonstrate writes with metrics
    println!("🔄 Running example operations with metrics...");
    println!();

    // Create sample traces
    let mut traces = Vec::new();
    for i in 0..10 {
        let trace = Trace::new(
            format!("trace_{}", i),
            "example-service".to_string(),
            Utc::now(),
        );
        traces.push(trace);
    }

    // Write traces (metrics are automatically recorded)
    println!("   Writing 10 traces...");
    writer.write_traces(traces).await?;
    println!("   ✅ Traces written");

    // Flush (metrics are automatically recorded)
    println!("   Flushing buffer...");
    writer.flush().await?;
    println!("   ✅ Buffer flushed");
    println!();

    // Demonstrate queries with metrics
    println!("   Querying traces...");
    let filters = Default::default();
    let results = repository.list(filters).await?;
    println!("   ✅ Found {} traces", results.len());
    println!();

    // Show current pool stats
    let stats = pool.stats();
    println!("📊 Current Pool Statistics:");
    println!("   Total Connections: {}", stats.postgres_size);
    println!("   Active: {}", stats.postgres_active);
    println!("   Idle: {}", stats.postgres_idle);
    println!("   Max: {}", stats.postgres_max_connections);
    println!("   Utilization: {:.1}%", stats.utilization_percent());
    println!();

    // Check health
    println!("🏥 Health Check:");
    let health = pool.health_check().await?;
    println!("   PostgreSQL: {}", if health.postgres_healthy { "✅ Healthy" } else { "❌ Unhealthy" });
    if let Some(redis_healthy) = health.redis_healthy {
        println!("   Redis: {}", if redis_healthy { "✅ Healthy" } else { "❌ Unhealthy" });
    }
    println!();

    println!("════════════════════════════════════════════════════════");
    println!("✨ Example completed successfully!");
    println!();
    println!("💡 Tips:");
    println!("   1. Check http://localhost:9090/health for health status");
    println!("   2. Check http://localhost:9090/metrics for all metrics");
    println!("   3. Import Grafana dashboards from docs/grafana/");
    println!("   4. Configure Prometheus to scrape localhost:9090");
    println!();
    println!("📚 See docs/MONITORING.md for complete documentation");
    println!("════════════════════════════════════════════════════════");
    println!();

    // Keep server running for a bit so you can check endpoints
    println!("⏳ Keeping server running for 60 seconds...");
    println!("   Press Ctrl+C to exit early");
    tokio::time::sleep(Duration::from_secs(60)).await;

    println!("👋 Shutting down...");
    pool.close().await;

    Ok(())
}
