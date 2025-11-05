use analytics_api::{app::build_app, config::Config, error::Result};
use dotenvy::dotenv;
use std::net::SocketAddr;
use tracing::{info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<()> {
    // Load environment variables from .env file
    dotenv().ok();

    // Initialize tracing/logging
    init_tracing();

    info!("Starting Analytics API service");

    // Load configuration
    let config = Config::from_env()?;
    info!(
        "Configuration loaded: host={}, port={}",
        config.app.host, config.app.port
    );

    // Build the application with all routes and middleware
    let app = build_app(config.clone()).await?;

    // Create server address
    let addr = SocketAddr::from((config.app.host, config.app.port));
    info!("Analytics API listening on {}", addr);

    // Start the server
    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app)
        .await
        .map_err(|e| analytics_api::error::Error::Server(format!("Server error: {}", e)))?;

    Ok(())
}

/// Initialize tracing subscriber for logging
fn init_tracing() {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        "analytics_api=debug,tower_http=debug,sqlx=info,axum=debug".into()
    });

    tracing_subscriber::registry()
        .with(filter)
        .with(tracing_subscriber::fmt::layer().with_target(true))
        .init();

    info!("Tracing initialized");
}
