# Multi-stage Dockerfile for Analytics API (Rust/Axum)

# ============================================================================
# Chef Stage (for dependency caching)
# ============================================================================
FROM rust:1.75-slim as chef

# Install cargo-chef
RUN cargo install cargo-chef

WORKDIR /app

# ============================================================================
# Planner Stage
# ============================================================================
FROM chef as planner

# Copy source code
COPY . .

# Generate recipe
RUN cargo chef prepare --recipe-path recipe.json

# ============================================================================
# Builder Stage
# ============================================================================
FROM chef as builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy recipe from planner
COPY --from=planner /app/recipe.json recipe.json

# Build dependencies (cached)
RUN cargo chef cook --release --recipe-path recipe.json

# Copy source code
COPY . .

# Build application
RUN cargo build --release

# ============================================================================
# Development Stage
# ============================================================================
FROM rust:1.75-slim as development

# Install system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install cargo-watch for hot reload
RUN cargo install cargo-watch

WORKDIR /app

# Copy source code
COPY . .

# Expose port
EXPOSE 8002

# Development command with hot reload
CMD ["cargo", "watch", "-x", "run"]

# ============================================================================
# Runtime Stage
# ============================================================================
FROM debian:bookworm-slim as runtime

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libpq5 \
    libssl3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/analytics-api /app/analytics-api

# Change ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8002/health || exit 1

# Run application
CMD ["/app/analytics-api"]

# ============================================================================
# Production Stage (alias for runtime)
# ============================================================================
FROM runtime as production
