# Multi-stage Dockerfile for KB API (Node.js/Express)

# ============================================================================
# Base Stage
# ============================================================================
FROM node:20-alpine as base

# Install system dependencies
RUN apk add --no-cache \
    curl \
    tini

# Set working directory
WORKDIR /app

# Use tini as entrypoint for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# ============================================================================
# Dependencies Stage
# ============================================================================
FROM base as dependencies

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev)
RUN npm ci

# ============================================================================
# Build Stage
# ============================================================================
FROM dependencies as build

# Copy source code
COPY src ./src

# Build TypeScript
RUN npm run build

# ============================================================================
# Development Stage
# ============================================================================
FROM base as development

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY src ./src

# Expose port
EXPOSE 8001

# Development command with hot reload
CMD ["npm", "run", "dev"]

# ============================================================================
# Production Dependencies Stage
# ============================================================================
FROM dependencies as production-dependencies

# Remove dev dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# ============================================================================
# Production Stage
# ============================================================================
FROM base as production

# Set NODE_ENV
ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /app

# Copy production dependencies
COPY --from=production-dependencies --chown=appuser:appuser /app/node_modules ./node_modules

# Copy built application
COPY --from=build --chown=appuser:appuser /app/dist ./dist
COPY --chown=appuser:appuser package*.json ./

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Production command
CMD ["node", "dist/index.js"]
