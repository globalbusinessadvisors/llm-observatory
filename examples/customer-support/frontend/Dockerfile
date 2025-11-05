# Multi-stage Dockerfile for Frontend (React/Vite)

# ============================================================================
# Base Stage
# ============================================================================
FROM node:20-alpine as base

# Install system dependencies
RUN apk add --no-cache \
    curl \
    tini

WORKDIR /app

# Use tini as entrypoint for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]

# ============================================================================
# Dependencies Stage
# ============================================================================
FROM base as dependencies

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# ============================================================================
# Development Stage
# ============================================================================
FROM base as development

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm ci

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Development command with hot reload
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]

# ============================================================================
# Build Stage
# ============================================================================
FROM dependencies as build

# Build arguments for environment variables
ARG VITE_CHAT_API_URL
ARG VITE_KB_API_URL
ARG VITE_ANALYTICS_API_URL
ARG VITE_WS_URL

ENV VITE_CHAT_API_URL=$VITE_CHAT_API_URL
ENV VITE_KB_API_URL=$VITE_KB_API_URL
ENV VITE_ANALYTICS_API_URL=$VITE_ANALYTICS_API_URL
ENV VITE_WS_URL=$VITE_WS_URL

# Copy source code
COPY . .

# Build application
RUN npm run build

# ============================================================================
# Production Stage
# ============================================================================
FROM nginx:alpine as production

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy built application from build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser && \
    chown -R appuser:appuser /usr/share/nginx/html && \
    chown -R appuser:appuser /var/cache/nginx && \
    chown -R appuser:appuser /var/log/nginx && \
    chown -R appuser:appuser /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appuser /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:3000 || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
