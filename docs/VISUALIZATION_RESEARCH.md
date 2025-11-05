# LLM Observatory Visualization Research

**Research Date:** 2025-11-05
**Focus:** Visualization approaches, dashboard patterns, and UI technologies for LLM observability

---

## Executive Summary

This document presents comprehensive research on visualization technologies and patterns for building an LLM observability platform. The analysis covers four technology stacks (Rust TUI, React-based web, Svelte-based web, and Grafana), real-time update strategies, key visualizations for MVP, and UX best practices specific to observability tools.

**Key Recommendations:**
- **Primary Stack:** Rust Ratatui for terminal dashboard + Axum WebSocket backend
- **Secondary Stack:** Svelte + WebSocket for web-based dashboard (lightweight, performant)
- **Real-time Strategy:** Server-Sent Events (SSE) for metrics, WebSocket for traces
- **Integration:** OpenTelemetry + OTLP protocol for standardization

---

## 1. Technology Stack Comparison

### 1.1 Rust Terminal UI (Ratatui)

**Description:** Native terminal dashboard using Ratatui, a Rust library for building rich TUIs.

**Advantages:**
- **Zero Latency UI:** Runs directly in terminal, no browser overhead
- **Lightweight:** Minimal memory footprint (~5-10MB vs 100MB+ for Electron)
- **Developer-Focused:** CLI-first approach matches developer workflow
- **Cross-Platform:** Works on Linux, macOS, Windows
- **Rich Ecosystem:** Widget library includes gauges, charts, tables, sparklines
- **Production Examples:** Used by bottom (system monitor), kdash (K8s dashboard), vector (observability pipeline)

**Disadvantages:**
- **Limited to Terminal:** Not accessible via web browser
- **Learning Curve:** Requires Rust knowledge for customization
- **Limited Chart Types:** Fewer complex visualization options vs web
- **No Mouse Interaction (Default):** Keyboard-driven interface

**Best Use Cases:**
- Developer debugging sessions
- SSH/remote server monitoring
- CI/CD pipeline integration
- Local development observability

**Implementation Details:**
```rust
// Key crates
ratatui = "0.29"           // TUI framework
crossterm = "0.28"         // Terminal manipulation
tokio = { version = "1", features = ["full"] }
sysinfo = "0.32"           // System stats
```

**UI Patterns from Bottom:**
- Split-pane layout (CPU, Memory, Disk, Network)
- Color-coded gauges (green=normal, yellow=warning, red=critical)
- Real-time graphs with sparklines
- Process tree navigation
- Configurable widgets via TOML

**Performance:**
- Renders at 60+ FPS
- <1% CPU usage during monitoring
- Handles 10,000+ metrics without lag

---

### 1.2 React + WebSocket Dashboard

**Description:** Modern web dashboard using React with WebSocket or SSE for real-time updates.

**Advantages:**
- **Mature Ecosystem:** Vast library of charting components (Recharts, Victory, D3)
- **Rich Visualizations:** Support for complex charts (flame graphs, sankey diagrams, heatmaps)
- **Wide Accessibility:** Browser-based, no installation required
- **Team Collaboration:** Multiple users can view same dashboard
- **Mobile Support:** Responsive design for mobile devices
- **State Management:** Redux/Zustand for complex data flows

**Disadvantages:**
- **Heavy Bundle:** Initial load 1-3MB (optimized), up to 10MB (unoptimized)
- **Memory Intensive:** 100-300MB browser memory usage
- **Re-render Overhead:** Virtual DOM diffing can cause lag with high-frequency updates
- **Deployment Complexity:** Requires web server, CDN, etc.

**Best Use Cases:**
- Team dashboards with shared access
- Executive/management reporting
- Complex multi-panel layouts
- Historical data analysis

**Implementation Details:**
```javascript
// Core dependencies
react: "^18.3"
react-router-dom: "^6.20"
recharts: "^2.12"           // Charts
@tanstack/react-query: "^5.0"  // Data fetching
socket.io-client: "^4.7"    // WebSocket

// Performance optimizations
react-window: "^1.8"        // Virtualization for large lists
use-debounce: "^10.0"       // Throttle updates
```

**Real-time Patterns:**
- WebSocket: Bi-directional, low latency (5-20ms), for interactive features
- SSE: Unidirectional, auto-reconnect, simpler auth, for metrics streams
- Polling: Fallback for restricted networks (5-30s intervals)

**Performance Benchmarks:**
- Initial Load: 1.2-2.5s (Lighthouse score: 75-85)
- Re-render: 16ms (60 FPS) for ~100 metric updates/sec
- Memory: 150-250MB steady state
- WebSocket Latency: 10-30ms per message

---

### 1.3 Svelte + WebSocket Dashboard

**Description:** Lightweight web dashboard using Svelte compiler with WebSocket integration.

**Advantages:**
- **Minimal Bundle Size:** 50-150KB (10x smaller than React)
- **Fast Startup:** 0.5-1.2s initial load (Lighthouse: 90-95)
- **Low Memory:** 60-120MB browser usage
- **No Virtual DOM:** Direct DOM manipulation = less overhead
- **Native Reactivity:** Built-in stores, no external state library needed
- **OpenTelemetry Support:** First-class OTEL integration in SvelteKit
- **Excellent Performance:** 19% faster startup, 21% better memory vs React

**Disadvantages:**
- **Smaller Ecosystem:** Fewer third-party components vs React
- **Less Tooling:** IDE support improving but not as mature
- **Hiring Pool:** Fewer developers with Svelte experience
- **Component Libraries:** Limited enterprise UI component libraries

**Best Use Cases:**
- Performance-critical dashboards
- Embedded dashboards (iframes, widgets)
- Real-time monitoring with frequent updates
- Resource-constrained environments

**Implementation Details:**
```javascript
// Core dependencies
svelte: "^4.2"
@sveltejs/kit: "^2.0"
svelte-chartjs: "^3.1"      // Chart.js wrapper
socket.io-client: "^4.7"
@opentelemetry/instrumentation-sveltekit: "^0.1"

// Real-time data handling
import { writable } from 'svelte/store';
const metrics = writable([]);
socket.on('metrics', data => metrics.update(m => [...m, data]));
```

**Performance Benchmarks:**
- Initial Load: 0.6-1.2s (better than React)
- Bundle Size: 80KB (vs 300KB React)
- Memory: 90MB (vs 150MB React)
- Re-render: Instant (no VDOM diffing)

**Observability Example (Logdash):**
- Real-time logs with zero YAML configuration
- Custom metrics visualization
- Auto-instrumentation with OpenLIT SDK
- Built-in tracing with SvelteKit OTEL support

---

### 1.4 Grafana + Custom Panels

**Description:** Industry-standard observability platform with extensible plugin system.

**Advantages:**
- **Proven at Scale:** Used by thousands of organizations
- **Rich Plugin Ecosystem:** 300+ data sources, 200+ visualizations
- **Alerting Built-in:** Sophisticated alert rules and notification channels
- **Multi-Tenant:** Role-based access control, teams, orgs
- **Data Source Flexibility:** Prometheus, InfluxDB, Elasticsearch, PostgreSQL, etc.
- **Query Builder:** Visual query editor for non-technical users
- **Dashboards as Code:** JSON export/import for GitOps

**Disadvantages:**
- **Heavy Infrastructure:** Requires separate Grafana server
- **Complex Setup:** Database backend, authentication, etc.
- **Customization Limits:** Plugin development requires specific framework
- **Opinionated:** Must conform to Grafana's data model
- **Resource Intensive:** 200-500MB memory for Grafana server

**Best Use Cases:**
- Enterprise deployments
- Multi-team observability platforms
- Integration with existing Prometheus/OTEL infrastructure
- When alerting is critical

**LLM Observability Integration:**
```yaml
# OpenLIT Dashboard Integration
data_source: prometheus
panels:
  - title: "Total Requests"
    type: stat
    query: sum(rate(llm_requests_total[5m]))

  - title: "Token Usage"
    type: timeseries
    query: |
      sum by (model) (
        rate(llm_tokens_total{type="completion"}[5m])
      )

  - title: "Cost Analysis"
    type: bar
    query: sum by (model) (llm_cost_usd_total)

  - title: "Latency Percentiles"
    type: graph
    queries:
      - histogram_quantile(0.50, llm_request_duration_seconds_bucket)
      - histogram_quantile(0.95, llm_request_duration_seconds_bucket)
      - histogram_quantile(0.99, llm_request_duration_seconds_bucket)
```

**Pre-built LLM Dashboards:**
- **OpenLIT Dashboard:** Grafana Cloud integration with 30+ AI tool auto-instrumentation
- **Pulze LLM Dashboard:** Cost vs token usage, request duration analysis
- **LangFuse Integration:** Token/cost tracking with model-wise breakdown

---

## 2. Recommended Dashboard Layouts

### 2.1 Terminal Dashboard Layout (Ratatui)

```
┌─────────────────────────────────────────────────────────────────────┐
│ LLM Observatory v0.1.0        [Q]uit [T]race [M]etrics [L]ogs      │
├─────────────────────────────────────────────────────────────────────┤
│ OVERVIEW                                      Updated: 2025-11-05   │
├───────────────────────┬─────────────────────────────────────────────┤
│ Requests/sec          │ ▆▇█▇▆▅▄▃▂▁ 1,234 req/s                     │
│ Tokens/sec            │ ▁▂▃▄▅▆▇█▇▆ 45.6K tok/s                     │
│ Avg Latency           │ ████████░░░░░ 245ms (p95: 890ms)           │
│ Error Rate            │ ▁▁▂▁▁▁▁▁▁▁ 0.02%                           │
├───────────────────────┴─────────────────────────────────────────────┤
│ MODEL BREAKDOWN                                                     │
├───────────────────┬──────────────┬──────────┬──────────┬───────────┤
│ Model             │ Requests     │ Tokens   │ Avg Lat  │ Cost/hr   │
├───────────────────┼──────────────┼──────────┼──────────┼───────────┤
│ gpt-4o            │ 12,345  45%  │ 2.3M     │ 320ms    │ $12.45    │
│ claude-sonnet-4.5 │  8,901  32%  │ 1.8M     │ 280ms    │ $9.20     │
│ gpt-4o-mini       │  6,234  23%  │ 890K     │ 180ms    │ $0.85     │
├───────────────────┴──────────────┴──────────┴──────────┴───────────┤
│ ACTIVE TRACES (Top 5 by duration)                                  │
├─────────────────────────────────────────────────────────────────────┤
│ [RUNNING] trace_abc123  gpt-4o     1,234ms  "Summarize document..." │
│ [RUNNING] trace_def456  claude-3.5   890ms  "Code review for..."   │
│ [COMPLETE] trace_ghi789 gpt-4o-mini 156ms  "Translate to Spanish"  │
├─────────────────────────────────────────────────────────────────────┤
│ ALERTS (2)                                                          │
├─────────────────────────────────────────────────────────────────────┤
│ [WARN] High latency on gpt-4o: p95=1.2s (threshold: 1s)            │
│ [INFO] Rate limit approaching: 85% of quota (reset in 12m)         │
└─────────────────────────────────────────────────────────────────────┘

Navigation: ↑↓ Scroll  →← Switch Tab  Enter Drill-down  Esc Back
```

**Design Principles:**
- **Visual Hierarchy:** Most critical metrics at top (requests, latency, errors)
- **Sparklines:** Inline trend visualization without dedicated chart area
- **Color Coding:** Green (healthy), yellow (warning), red (critical)
- **Keyboard Navigation:** All features accessible via keyboard shortcuts
- **Contextual Actions:** Bottom bar shows available actions for current view

---

### 2.2 Web Dashboard Layout (React/Svelte)

```
┌──────────────────────────────────────────────────────────────────────┐
│  LLM Observatory                    [Settings] [Export] [Share] [@user] │
├──────────────────────────────────────────────────────────────────────┤
│ Dashboard > Overview                                    Last 1 hour ▼ │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐│
│ │ Requests     │ │ Tokens       │ │ Avg Latency  │ │ Cost         ││
│ │              │ │              │ │              │ │              ││
│ │  1.2K/s      │ │  45.6K/s     │ │   245ms      │ │  $1.23/hr    ││
│ │  ↑ 12%       │ │  ↑ 8%        │ │  ↓ 5%        │ │  ↑ 10%       ││
│ └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘│
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Request Volume by Model                                         │ │
│ │                                                                 │ │
│ │ 2K│                                            ╭─ gpt-4o        │ │
│ │   │                                      ╭─────╯               │ │
│ │ 1K│                          ╭───────────╯     ╭─ claude-3.5  │ │
│ │   │              ╭───────────╯                ╱                │ │
│ │ 0 │──────────────╯─────────────────────────────                │ │
│ │   └──────────────────────────────────────────────────────────  │ │
│ │     10:00    10:15    10:30    10:45    11:00    11:15        │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│ ┌────────────────────────────┐ ┌────────────────────────────────┐  │
│ │ Latency Distribution       │ │ Token Usage Breakdown          │  │
│ │                            │ │                                │  │
│ │     ▂▄▆█▆▄▂                │ │  Input:  65%  ████████████    │  │
│ │   ▁▄█████████▄▁            │ │  Output: 30%  █████████       │  │
│ │  ▂██████████████▂          │ │  Cached:  5%  ██              │  │
│ │ ▁███████████████▁          │ │                                │  │
│ │ 0ms   500ms   1s   2s      │ │  Total: 2.3M tokens/hr        │  │
│ └────────────────────────────┘ └────────────────────────────────┘  │
│                                                                       │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Recent Traces (Click to expand)                                 │ │
│ ├─────────────────────────────────────────────────────────────────┤ │
│ │ ● trace_abc123  gpt-4o     1.2s  [▓▓▓▓▓▓▓▓▓▓░░] Summarize...  │ │
│ │ ● trace_def456  claude-3.5 890ms [▓▓▓▓▓▓▓░░░░░] Code review...│ │
│ │ ✓ trace_ghi789  gpt-4o-mini 156ms [▓▓░░░░░░░░░░] Translate... │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘

Left Sidebar: [Overview] [Traces] [Models] [Alerts] [Settings]
```

**Design Principles:**
- **Card-Based Layout:** Modular panels for easy rearrangement
- **Responsive Grid:** Adapts to screen size (desktop → tablet → mobile)
- **Interactive Charts:** Hover for details, click to drill down
- **Color Consistency:** Use same colors for model across all charts
- **Time Range Selector:** Quick filters (1h, 6h, 24h, 7d, custom)
- **Real-time Indicators:** Pulsing dot or "Live" badge for active updates

---

### 2.3 Trace Detail View (All Platforms)

```
┌──────────────────────────────────────────────────────────────────────┐
│ Trace: trace_abc123                                        Duration: 1.2s │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│ Timeline (Gantt Chart)                                                │
│ ┌───────────────────────────────────────────────────────────────┐   │
│ │ llm.request              ├─────────────────────────────────┤  │   │
│ │   ├─ tokenize            ├──┤                                  │   │
│ │   ├─ prefill             |  ├────────┤                         │   │
│ │   ├─ generate            |          ├─────────────────┤        │   │
│ │   └─ detokenize          |                           ├─┤       │   │
│ │ 0ms      200ms    400ms    600ms    800ms   1000ms   1200ms   │   │
│ └───────────────────────────────────────────────────────────────┘   │
│                                                                       │
│ Span Details                                                          │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Name:     llm.request                                           │ │
│ │ Duration: 1,234ms                                               │ │
│ │ Model:    gpt-4o                                                │ │
│ │ Status:   OK                                                    │ │
│ │                                                                 │ │
│ │ Attributes:                                                     │ │
│ │   llm.model_name:          "gpt-4o"                             │ │
│ │   llm.request.max_tokens:  1000                                 │ │
│ │   llm.usage.input_tokens:  150                                  │ │
│ │   llm.usage.output_tokens: 890                                  │ │
│ │   llm.usage.total_tokens:  1040                                 │ │
│ │   llm.cost_usd:            0.0234                               │ │
│ │                                                                 │ │
│ │ Prompt (first 200 chars):                                       │ │
│ │   "Summarize the following document in 3 bullet points..."      │ │
│ │                                                                 │ │
│ │ Response (first 200 chars):                                     │ │
│ │   "- Key finding #1: The analysis reveals...\n- Key..."        │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│ Latency Breakdown                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ Tokenize:    12ms   1%  ▓                                       │ │
│ │ Prefill:    234ms  19%  ▓▓▓▓▓                                   │ │
│ │ Generate:   890ms  72%  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓                     │ │
│ │ Detokenize:  98ms   8%  ▓▓                                      │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

**Key Elements:**
- **Gantt Timeline:** Horizontal bars show nested spans and parallelism
- **Latency Breakdown:** Pie/bar chart showing prefill vs decode time
- **Attributes Table:** All OpenTelemetry semantic conventions
- **Prompt/Response Preview:** Truncated with "Show full" expansion
- **Export Options:** JSON, share link, copy trace ID

---

## 3. Real-time Data Display Strategies

### 3.1 Technology Comparison

| Feature | WebSocket | Server-Sent Events (SSE) | Polling |
|---------|-----------|--------------------------|---------|
| **Direction** | Bi-directional | Server → Client only | Client → Server |
| **Protocol** | WS/WSS | HTTP/HTTPS | HTTP/HTTPS |
| **Latency** | 5-20ms | 10-30ms | 1s-30s (interval) |
| **Auto-Reconnect** | Manual | Automatic (EventSource) | N/A |
| **Message Format** | Binary/Text | Text (UTF-8) | JSON |
| **Overhead** | Low | Low | High (repeated headers) |
| **Use Case** | Interactive, 2-way | Metrics stream, logs | Fallback, simple |
| **Browser Support** | All modern | All modern | Universal |
| **Proxy-Friendly** | Sometimes | Yes (HTTP) | Yes |
| **Authentication** | Custom headers | URL params, cookies | Standard HTTP |

---

### 3.2 Recommended Strategy

**Hybrid Approach (Best of Both Worlds):**

```
┌──────────────┐
│   Client     │
│  Dashboard   │
└───┬─────┬────┘
    │     │
    │     │ WebSocket (traces, interactive)
    │     │
    │     ▼
    │  ┌─────────────────┐
    │  │ Rust Axum Server│
    │  │  /ws/traces     │
    │  └─────────────────┘
    │
    │ SSE (metrics, logs, alerts)
    │
    ▼
 ┌─────────────────┐
 │ Rust Axum Server│
 │  /events/metrics│
 └─────────────────┘
```

**Implementation:**

**SSE for Metrics (Recommended Primary):**
- **Why:** Auto-reconnect, simpler auth, works with HTTP/2 multiplexing
- **What:** Time-series metrics (requests/sec, latency, token usage)
- **Update Frequency:** 1-5 second intervals (configurable)
- **Backpressure:** Server-side aggregation, drop old events if client slow

```rust
// Axum SSE endpoint
use axum::{
    response::sse::{Event, KeepAlive, Sse},
    routing::get,
    Router,
};
use futures::stream::{self, Stream};
use std::time::Duration;

async fn metrics_stream() -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let stream = stream::repeat_with(|| {
        let metrics = get_current_metrics(); // Fetch from aggregator
        Event::default()
            .json_data(metrics)
            .unwrap()
    })
    .throttle(Duration::from_secs(1)); // 1 update/sec

    Sse::new(stream).keep_alive(KeepAlive::default())
}

let app = Router::new()
    .route("/events/metrics", get(metrics_stream));
```

**WebSocket for Traces (Interactive Data):**
- **Why:** Low latency for live trace updates, bi-directional for filters
- **What:** Active traces, span events, real-time search results
- **Update Frequency:** Event-driven (immediate on new trace)
- **Backpressure:** Client ACK, server buffer with max size

```rust
// Axum WebSocket endpoint
use axum::{
    extract::ws::{WebSocket, WebSocketUpgrade},
    response::Response,
};

async fn ws_handler(ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    let (tx, mut rx) = tokio::sync::mpsc::channel(100);

    // Subscribe to trace events
    let _subscription = TRACE_BROADCASTER.subscribe(tx).await;

    loop {
        tokio::select! {
            // Send traces to client
            Some(trace) = rx.recv() => {
                socket.send(Message::Text(serde_json::to_string(&trace)?)).await?;
            }
            // Receive filters from client
            Some(Ok(Message::Text(filter))) = socket.recv() => {
                apply_filter(filter).await;
            }
        }
    }
}
```

**Polling as Fallback:**
- **When:** SSE/WS blocked by corporate firewall/proxy
- **Interval:** 5-10 seconds (conservative to avoid hammering)
- **Detection:** Client tries WS/SSE, falls back on error

---

### 3.3 Data Aggregation for Visualization

**Challenge:** LLMs generate high-cardinality metrics (per-request traces, token counts, latencies).

**Solution:** Multi-level aggregation strategy

```
┌─────────────────────────────────────────────────────────────────┐
│ Data Flow: Raw Events → Aggregation → Storage → Visualization  │
└─────────────────────────────────────────────────────────────────┘

1. Raw Events (High Volume)
   └─> 1,000+ requests/sec
       └─> Each trace: 5-20 spans
           └─> 5K-20K events/sec

2. Real-time Aggregation (In-Memory)
   └─> Window-based: 1s, 5s, 1m, 5m
   └─> Metrics: count, sum, avg, min, max, p50, p95, p99
   └─> Group by: model, status, error_type

3. Storage Strategy
   ├─> Hot Data (1 hour): Full resolution (1s granularity)
   ├─> Warm Data (24 hours): Downsampled (1m granularity)
   └─> Cold Data (30 days): Downsampled (5m granularity)

4. Visualization Query
   └─> Dashboard requests "last 1 hour"
       └─> Returns 3,600 data points (1s each)
       └─> Client decimates to ~100 points for chart
```

**Aggregation Implementation:**

```rust
use std::collections::HashMap;
use std::time::{Duration, Instant};

struct MetricAggregator {
    window: Duration,
    buckets: HashMap<String, Bucket>,
}

struct Bucket {
    count: u64,
    sum: f64,
    min: f64,
    max: f64,
    histogram: [u64; 100], // For percentiles
}

impl MetricAggregator {
    fn ingest(&mut self, metric: Metric) {
        let key = format!("{}:{}:{}", metric.name, metric.model, metric.status);
        let bucket = self.buckets.entry(key).or_insert(Bucket::new());

        bucket.count += 1;
        bucket.sum += metric.value;
        bucket.min = bucket.min.min(metric.value);
        bucket.max = bucket.max.max(metric.value);
        bucket.histogram[Self::bucket_index(metric.value)] += 1;
    }

    fn flush(&mut self) -> Vec<AggregatedMetric> {
        self.buckets.drain().map(|(key, bucket)| {
            AggregatedMetric {
                name: key,
                count: bucket.count,
                avg: bucket.sum / bucket.count as f64,
                min: bucket.min,
                max: bucket.max,
                p50: Self::percentile(&bucket.histogram, 0.50),
                p95: Self::percentile(&bucket.histogram, 0.95),
                p99: Self::percentile(&bucket.histogram, 0.99),
            }
        }).collect()
    }
}
```

**Downsampling Strategy:**

```rust
// Keep different resolutions based on age
async fn downsample_old_data(db: &Database) {
    // After 1 hour: aggregate to 1-minute buckets
    db.aggregate("1s_metrics", "1m_metrics", Duration::from_hours(1)).await;

    // After 24 hours: aggregate to 5-minute buckets
    db.aggregate("1m_metrics", "5m_metrics", Duration::from_hours(24)).await;

    // After 7 days: aggregate to 1-hour buckets
    db.aggregate("5m_metrics", "1h_metrics", Duration::from_days(7)).await;

    // Delete raw data older than retention policy
    db.delete_older_than("1s_metrics", Duration::from_hours(1)).await;
}
```

---

## 4. Key Visualizations to Prioritize for MVP

### 4.1 Priority 1 (Must-Have)

#### 1. **Request Rate Time Series**
```
Visualization: Line chart
Metrics: requests/sec (by model, by status)
Update: Real-time (1s)
Y-axis: Request count
X-axis: Time (last 5m, 1h, 6h)
Drill-down: Click model → filter to that model
```

**Why:** Core health indicator. Shows traffic patterns, load spikes.

---

#### 2. **Latency Percentile Chart**
```
Visualization: Multi-line chart (p50, p95, p99)
Metrics: request_duration_ms
Update: Real-time (5s)
Y-axis: Latency (ms, log scale optional)
X-axis: Time
Color: p50=green, p95=yellow, p99=red
```

**Why:** Latency is critical for user experience. Percentiles reveal tail latency.

**Example:**
```
1000ms │                                            ╭─── p99
       │                                      ╭─────╯
 500ms │                          ╭───────────╯     ╭─── p95
       │              ╭───────────╯                ╱
 100ms │──────────────╯────────────────────────────── p50
       └────────────────────────────────────────────
```

---

#### 3. **Token Usage Breakdown**
```
Visualization: Stacked bar chart (hourly) or pie chart
Metrics: input_tokens, output_tokens, cached_tokens
Update: Real-time (5s) + historical
Grouping: By model
```

**Why:** Direct correlation to cost. Helps identify expensive requests.

**Example:**
```
gpt-4o       ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ (65% input, 30% output, 5% cached)
claude-3.5   ▓▓▓▓▓▓▓▓▓▓ (70% input, 28% output, 2% cached)
gpt-4o-mini  ▓▓▓▓▓ (60% input, 40% output, 0% cached)
```

---

#### 4. **Cost Dashboard**
```
Visualization:
  - Big number: Total cost/hour, cost/day
  - Pie chart: Cost by model
  - Time series: Cost over time
Metrics: cost_usd (calculated from tokens * model pricing)
Update: Real-time (10s)
```

**Why:** Budget tracking. Immediate visibility into spend.

**Example:**
```
┌──────────────────┐  ┌────────────────────────────┐
│ Current Cost     │  │ Cost by Model              │
│  $12.45/hr       │  │  gpt-4o:     65% ($8.12)   │
│  ↑ 15% vs avg    │  │  claude-3.5: 30% ($3.74)   │
└──────────────────┘  │  gpt-4o-mini: 5% ($0.59)   │
                      └────────────────────────────┘
```

---

#### 5. **Error Rate & Status Codes**
```
Visualization:
  - Gauge: Error rate %
  - Table: Top errors by type
Update: Real-time (5s)
Alert threshold: >1% error rate
```

**Why:** Immediate detection of API failures, rate limits, bad requests.

**Example:**
```
Error Rate: 0.12%  (below threshold ✓)

Recent Errors:
- 429 Rate Limit: 45 (gpt-4o, last 5m)
- 500 Server Error: 12 (claude-3.5, last 5m)
- 400 Bad Request: 8 (gpt-4o-mini, last 5m)
```

---

#### 6. **Active Traces Table**
```
Visualization: Scrollable table
Columns: Trace ID, Model, Duration, Status, Preview
Update: Real-time (1s, WebSocket)
Sorting: By duration (slowest first)
Click: Drill-down to trace detail
```

**Why:** Live debugging. See exactly what's happening right now.

---

### 4.2 Priority 2 (Should-Have)

#### 7. **Latency Heatmap (Distribution over Time)**
```
Visualization: 2D heatmap
X-axis: Time (last 1 hour)
Y-axis: Latency buckets (0-100ms, 100-200ms, ..., >5s)
Color: Request count (blue=few, red=many)
```

**Why:** Reveals latency patterns invisible in percentile charts.

**Example from Grafana:**
```
5s+    │ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
2-5s   │ ░░░░░░░░░░░░░░░▒▒░░░░░░░░░░░░░░░
1-2s   │ ░░░░░░░░░░░░▒▒▒▒▓▓▒▒░░░░░░░░░░░░
500ms-1s│ ░░░░░░░░▒▒▒▒▓▓▓▓██▓▓▓▒▒░░░░░░░░
200-500ms│░░░▒▒▓▓▓▓████████████▓▓▒▒░░░░░
0-200ms│▒▒▓▓████████████████████▓▓▒▒░░░
       └─────────────────────────────────
       10:00          10:30         11:00
```

---

#### 8. **Model Comparison View**
```
Visualization: Multi-metric comparison table
Metrics: Req/s, Avg Latency, Cost/1K tokens, Error Rate
Models: gpt-4o, claude-3.5, gpt-4o-mini, etc.
```

**Why:** Choose right model for use case (cost vs speed vs quality).

**Example:**
```
┌───────────────┬─────────┬──────────┬──────────┬───────────┐
│ Model         │ Req/s   │ Avg Lat  │ Cost/1K  │ Error %   │
├───────────────┼─────────┼──────────┼──────────┼───────────┤
│ gpt-4o        │ 12.3    │ 320ms    │ $0.0225  │ 0.02%     │
│ claude-3.5    │ 8.9     │ 280ms    │ $0.0180  │ 0.01%     │
│ gpt-4o-mini   │ 6.2     │ 180ms    │ $0.0002  │ 0.05%     │
└───────────────┴─────────┴──────────┴──────────┴───────────┘
```

---

#### 9. **Trace Flamegraph (Latency Breakdown)**
```
Visualization: Flamegraph (hierarchical)
Data: Span hierarchy from trace
Width: Duration (ms)
Color: Span type (compute=red, I/O=blue, cache=green)
```

**Why:** Identify bottlenecks within request (prefill vs decode, network, etc.).

**Example:**
```
llm.request (1234ms) ████████████████████████████████████
├─ tokenize (12ms)    █
├─ prefill (234ms)    ███████
├─ generate (890ms)   ███████████████████████████
└─ detokenize (98ms)  ████
```

---

#### 10. **Prompt/Response Inspector**
```
Visualization: Searchable table + detail view
Columns: Timestamp, Model, Prompt (truncated), Tokens, Cost
Search: Full-text search in prompts/responses
```

**Why:** Debug specific requests, analyze prompt patterns.

---

### 4.3 Priority 3 (Nice-to-Have)

- **Service Dependency Graph:** Visualize if LLM calls other services
- **Anomaly Detection Chart:** ML-based outlier highlighting
- **Custom Dashboards:** User-configurable panels
- **Alert History:** Timeline of triggered alerts
- **Quota/Rate Limit Tracker:** Visual countdown to API limits

---

## 5. UX Best Practices for Observability Tools

### 5.1 Visual Hierarchy & Information Architecture

**Golden Rule:** Answer "Is my system healthy?" in <3 seconds.

```
Level 1: Overview (3-second glance)
├─ Traffic light status (green/yellow/red)
├─ Request rate trend (up/down arrow)
├─ Latency gauge (current vs threshold)
└─ Error count (big number)

Level 2: Category Details (30-second scan)
├─ Model breakdown (which model is slow?)
├─ Error types (what's failing?)
└─ Cost trends (spending increasing?)

Level 3: Individual Investigation (5-minute deep dive)
├─ Single trace flamegraph
├─ Prompt/response inspection
└─ Related traces (same prompt pattern)
```

**Implementation:**
- **Top Section:** High-level KPIs (requests, latency, errors, cost)
- **Middle Section:** Time-series charts (trends over time)
- **Bottom Section:** Tables (individual traces, errors, logs)
- **Side Panel:** Filters (time range, model, status)

---

### 5.2 Alert & Anomaly Highlighting

**Design Patterns:**

1. **Traffic Light Colors (Universal):**
   - Green: All metrics within normal range
   - Yellow: Warning threshold exceeded (e.g., p95 > 1s)
   - Red: Critical threshold exceeded (e.g., error rate > 5%)

2. **Pulsing Animation:** For active alerts (draws eye immediately)

3. **Alert Banner:** Top of dashboard, dismissible
   ```
   ┌──────────────────────────────────────────────────────────┐
   │ ⚠ WARNING: gpt-4o latency p95=1.2s (threshold: 1s)      │
   │ Last 5 minutes: 12 slow requests. [View Traces] [Dismiss]│
   └──────────────────────────────────────────────────────────┘
   ```

4. **Contextual Annotations:** Mark deployments, config changes on charts
   ```
   Latency Chart:
   │     ▲ Deploy v1.2.3
   │     │
   500ms│     │  ╭───── (spike after deploy)
   │     │╭─╯
   100ms│─────╯────
   ```

5. **Anomaly Detection Indicators:**
   - **Statistical:** Shade area ±2σ from mean, highlight outliers
   - **Visual:** Different color/pattern for anomalous data points

**Alert Prioritization:**
```
P0 (Critical): System down, >10% error rate
  └─> Red banner, browser notification, PagerDuty

P1 (High): Latency >2s, error rate >1%
  └─> Yellow banner, dashboard notification

P2 (Medium): Cost spike >50% above average
  └─> Info banner, email digest

P3 (Low): New model detected, minor config change
  └─> Subtle icon, no interruption
```

---

### 5.3 Drill-down Capabilities

**Pattern: Overview → Detail (3-Click Rule)**

```
Click 1: Dashboard → Model breakdown
  └─> Show all metrics for selected model

Click 2: Model chart → Time range selection
  └─> Filter to specific time window (e.g., 10:30-10:35)

Click 3: Time range → Individual trace
  └─> Show full trace detail with spans
```

**Breadcrumb Navigation:**
```
Home > Overview > gpt-4o > 2025-11-05 10:30-10:35 > trace_abc123
```

**Contextual Drill-downs:**
- **From chart:** Click data point → traces in that time bucket
- **From table:** Click trace ID → full trace view
- **From error:** Click error type → all traces with that error

**Drill-down UI Patterns:**

1. **Modal Overlay (Web):** Keep context, easy back navigation
2. **Side Panel (Web):** Split view (list + detail)
3. **New Tab (Terminal):** Switch between overview and detail tabs

---

### 5.4 Search & Filter Patterns

**Filter Bar (Always Visible):**
```
┌──────────────────────────────────────────────────────────┐
│ Time: [Last 1 hour ▼] Model: [All ▼] Status: [All ▼]    │
│ Search: [trace ID, prompt, error...] 🔍                   │
└──────────────────────────────────────────────────────────┘
```

**Filter Types:**

1. **Time Range:**
   - Quick filters: Last 5m, 15m, 1h, 6h, 24h, 7d
   - Custom range: Date/time picker
   - Relative: "Last X minutes from now" (auto-updates)

2. **Model Filter:**
   - Multi-select: `gpt-4o`, `claude-3.5`, `gpt-4o-mini`
   - Supports wildcards: `gpt-*`

3. **Status Filter:**
   - `success`, `error`, `timeout`, `rate_limited`

4. **Full-Text Search:**
   - Search in: prompts, responses, trace IDs, error messages
   - Syntax: `error:rate_limit model:gpt-4o`

**Filter Persistence:**
- Save filter state in URL query params
- Shareable links with filters applied
- Save common filter combos as "Views"

---

### 5.5 Export & Reporting Features

**Export Formats:**

1. **CSV/TSV (Tabular Data):**
   - Metrics: Time-series data, model comparison table
   - Use case: Import into Excel, Google Sheets

2. **JSON (Structured Data):**
   - Traces: Full trace with all spans/attributes
   - Use case: Post-processing, custom analysis

3. **PNG/SVG (Charts):**
   - Visualizations: Download chart as image
   - Use case: Reports, presentations, Slack/email

4. **API Endpoints (Programmatic):**
   ```bash
   # Get metrics for last hour
   curl -H "Authorization: Bearer $TOKEN" \
     https://observatory.example.com/api/metrics?range=1h&format=json

   # Get specific trace
   curl https://observatory.example.com/api/traces/abc123
   ```

**Reporting Features:**

1. **Scheduled Reports:**
   - Daily/weekly email digest with:
     - Summary stats (requests, cost, errors)
     - Top 5 slowest traces
     - Anomaly alerts

2. **Dashboard Sharing:**
   - Public link: Read-only, no auth required
   - Time-limited: Expires after 7 days
   - Snapshot: Static HTML with embedded data

3. **Alerting Integrations:**
   - Slack: Post alert to channel
   - PagerDuty: Create incident
   - Webhook: POST JSON to custom endpoint

**Export UI:**
```
┌─────────────────────────────────┐
│ Export Data                     │
├─────────────────────────────────┤
│ Format:  ○ CSV  ● JSON  ○ PNG   │
│ Range:   Last 1 hour            │
│ Filter:  Applied (2 active)     │
│                                 │
│ [Cancel]  [Download]            │
└─────────────────────────────────┘
```

---

### 5.6 Performance & Responsiveness

**Target Performance Metrics:**

```
Initial Load:
├─ Terminal (Ratatui):  <100ms (instant)
├─ Web (Svelte):        <1.2s (Time to Interactive)
└─ Web (React):         <2.5s (Time to Interactive)

Update Latency:
├─ SSE metric update:   50-200ms (network + render)
├─ WebSocket trace:     10-50ms (network + render)
└─ Chart re-render:     <16ms (60 FPS)

Data Freshness:
├─ Real-time metrics:   1-5s delay (acceptable)
├─ Active traces:       <1s delay (immediate)
└─ Historical data:     No delay (query from DB)
```

**Performance Optimizations:**

1. **Lazy Loading:** Load only visible data (virtualized lists)
2. **Debouncing:** Throttle updates to 60 FPS max
3. **Delta Updates:** Send only changed data, not full snapshot
4. **Client-Side Decimation:** Downsample 10,000 points → 100 for chart
5. **Pagination:** Load traces 50 at a time, infinite scroll
6. **Caching:** Browser cache static assets, service worker for offline

**Responsive Design (Web):**
```
Desktop (>1200px):  Multi-column grid, side-by-side charts
Tablet (768-1200px): 2-column grid, stacked charts
Mobile (<768px):    Single column, collapsible sections
```

---

### 5.7 Accessibility (a11y)

**Requirements:**

1. **Keyboard Navigation:** All features accessible without mouse
   - Tab: Navigate between elements
   - Arrow keys: Navigate within charts/tables
   - Escape: Close modal/panel
   - Enter: Activate/select

2. **Screen Reader Support:**
   - ARIA labels for charts: "Request rate: 1,234 per second"
   - Table headers: Proper `<th>` tags
   - Alt text for visualizations

3. **Color Blindness:**
   - Don't rely on color alone (use icons + color)
   - Use colorblind-safe palettes (e.g., Viridis, Okabe-Ito)
   - Configurable themes (normal, protanopia, deuteranopia)

4. **Contrast Ratios:**
   - Text: 4.5:1 minimum (WCAG AA)
   - Charts: 3:1 minimum for data visualization

---

## 6. Integration Approach with Rust Backend

### 6.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   LLM Observatory Stack                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │ Frontend Layer (Choose One or Both)                │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • Ratatui Terminal UI (Rust)                       │   │
│  │ • Svelte Web UI (TypeScript) + WebSocket/SSE       │   │
│  └────────────────┬───────────────────────────────────┘   │
│                   │                                        │
│                   ▼                                        │
│  ┌────────────────────────────────────────────────────┐   │
│  │ Axum Web Server (Rust)                             │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • REST API (/api/metrics, /api/traces)             │   │
│  │ • WebSocket (/ws/traces)                           │   │
│  │ • SSE (/events/metrics)                            │   │
│  │ • Static file serving (web UI assets)              │   │
│  └────────────────┬───────────────────────────────────┘   │
│                   │                                        │
│                   ▼                                        │
│  ┌────────────────────────────────────────────────────┐   │
│  │ OpenTelemetry Integration (Rust)                   │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • opentelemetry crate (0.29)                       │   │
│  │ • opentelemetry-otlp (OTLP exporter)               │   │
│  │ • axum-otel-metrics (HTTP metrics)                 │   │
│  │ • axum-tracing-opentelemetry (distributed tracing) │   │
│  └────────────────┬───────────────────────────────────┘   │
│                   │                                        │
│                   ▼                                        │
│  ┌────────────────────────────────────────────────────┐   │
│  │ Data Layer                                         │   │
│  ├────────────────────────────────────────────────────┤   │
│  │ • In-Memory: DashMap (concurrent HashMap)          │   │
│  │ • Time-Series DB: TimescaleDB or ClickHouse        │   │
│  │ • Trace Storage: Jaeger or Tempo (optional)        │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### 6.2 Rust Backend Implementation

**Project Structure:**
```
llm-observatory/
├── crates/
│   ├── observatory-core/        # Core logic
│   │   ├── src/
│   │   │   ├── metrics.rs       # Metric definitions
│   │   │   ├── tracing.rs       # Tracing setup
│   │   │   ├── aggregator.rs    # Data aggregation
│   │   │   └── storage.rs       # DB interface
│   │   └── Cargo.toml
│   │
│   ├── observatory-server/      # Axum web server
│   │   ├── src/
│   │   │   ├── main.rs
│   │   │   ├── api/             # REST endpoints
│   │   │   │   ├── metrics.rs
│   │   │   │   ├── traces.rs
│   │   │   │   └── mod.rs
│   │   │   ├── ws.rs            # WebSocket handler
│   │   │   ├── sse.rs           # SSE handler
│   │   │   └── middleware.rs    # Auth, CORS, etc.
│   │   └── Cargo.toml
│   │
│   └── observatory-tui/         # Ratatui terminal UI
│       ├── src/
│       │   ├── main.rs
│       │   ├── app.rs           # App state
│       │   ├── ui/              # UI components
│       │   │   ├── overview.rs
│       │   │   ├── traces.rs
│       │   │   └── mod.rs
│       │   └── client.rs        # API client
│       └── Cargo.toml
│
├── web-ui/                      # Svelte frontend (optional)
│   ├── src/
│   │   ├── routes/
│   │   ├── lib/components/
│   │   └── lib/stores/
│   └── package.json
│
└── Cargo.toml                   # Workspace
```

---

**Key Dependencies (Cargo.toml):**

```toml
[workspace]
members = ["crates/*"]

[workspace.dependencies]
# Web framework
axum = "0.8"
tokio = { version = "1", features = ["full"] }
tower = "0.5"
tower-http = { version = "0.6", features = ["fs", "cors", "trace"] }

# OpenTelemetry
opentelemetry = "0.29"
opentelemetry-otlp = "0.29"
opentelemetry_sdk = "0.29"
opentelemetry-semantic-conventions = "0.29"
axum-otel-metrics = "0.11"
axum-tracing-opentelemetry = "0.22"
tracing = "0.1"
tracing-subscriber = "0.3"

# Serialization
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# Database (choose one)
sqlx = { version = "0.8", features = ["postgres", "runtime-tokio"] }
# or
clickhouse = "0.14"

# Concurrency
dashmap = "6.0"  # Concurrent HashMap
parking_lot = "0.12"  # Fast mutexes

# TUI (for terminal UI)
ratatui = "0.29"
crossterm = "0.28"

# Time
chrono = "0.4"
```

---

### 6.3 OpenTelemetry Integration

**Setup (main.rs):**

```rust
use axum::{Router, routing::get};
use axum_otel_metrics::HttpMetricsLayerBuilder;
use axum_tracing_opentelemetry::middleware::{OtelAxumLayer, OtelInResponseLayer};
use opentelemetry::{global, KeyValue};
use opentelemetry_otlp::WithExportConfig;
use opentelemetry_sdk::{Resource, trace::TracerProvider};
use tower_http::trace::TraceLayer;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() {
    // Initialize OpenTelemetry
    let tracer_provider = init_tracer_provider();
    global::set_tracer_provider(tracer_provider);

    // Initialize tracing subscriber
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    // Build Axum app with OTEL middleware
    let metrics_layer = HttpMetricsLayerBuilder::new()
        .with_service_name("llm-observatory")
        .build();

    let app = Router::new()
        .route("/api/metrics", get(api::metrics::get_metrics))
        .route("/api/traces", get(api::traces::get_traces))
        .route("/ws/traces", get(ws::traces_handler))
        .route("/events/metrics", get(sse::metrics_stream))
        .layer(OtelInResponseLayer)  // Add trace ID to response headers
        .layer(OtelAxumLayer::default())  // Automatic span creation
        .layer(metrics_layer)  // HTTP metrics (req/s, latency, etc.)
        .layer(TraceLayer::new_for_http());  // Request logging

    // Start server
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

fn init_tracer_provider() -> TracerProvider {
    opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://localhost:4317")  // OTLP gRPC endpoint
        )
        .with_trace_config(
            opentelemetry_sdk::trace::Config::default()
                .with_resource(Resource::new(vec![
                    KeyValue::new("service.name", "llm-observatory"),
                    KeyValue::new("service.version", env!("CARGO_PKG_VERSION")),
                ]))
        )
        .install_batch(opentelemetry_sdk::runtime::Tokio)
        .expect("Failed to initialize tracer")
}
```

---

**Custom LLM Metrics:**

```rust
use opentelemetry::{
    global,
    metrics::{Counter, Histogram, Meter},
    KeyValue,
};

pub struct LLMMetrics {
    requests_total: Counter<u64>,
    tokens_total: Counter<u64>,
    request_duration: Histogram<f64>,
    cost_usd_total: Counter<f64>,
}

impl LLMMetrics {
    pub fn new() -> Self {
        let meter = global::meter("llm-observatory");

        Self {
            requests_total: meter
                .u64_counter("llm.requests.total")
                .with_description("Total number of LLM requests")
                .init(),

            tokens_total: meter
                .u64_counter("llm.tokens.total")
                .with_description("Total tokens processed")
                .init(),

            request_duration: meter
                .f64_histogram("llm.request.duration")
                .with_description("LLM request duration in seconds")
                .with_unit("s")
                .init(),

            cost_usd_total: meter
                .f64_counter("llm.cost.usd.total")
                .with_description("Total cost in USD")
                .init(),
        }
    }

    pub fn record_request(
        &self,
        model: &str,
        input_tokens: u64,
        output_tokens: u64,
        duration_secs: f64,
        cost_usd: f64,
    ) {
        let attrs = &[KeyValue::new("model", model.to_string())];

        self.requests_total.add(1, attrs);
        self.tokens_total.add(
            input_tokens + output_tokens,
            &[
                KeyValue::new("model", model.to_string()),
                KeyValue::new("type", "total"),
            ],
        );
        self.request_duration.record(duration_secs, attrs);
        self.cost_usd_total.add(cost_usd, attrs);
    }
}
```

---

### 6.4 WebSocket Implementation

```rust
use axum::{
    extract::ws::{Message, WebSocket, WebSocketUpgrade},
    response::Response,
};
use futures::{sink::SinkExt, stream::StreamExt};
use serde::{Deserialize, Serialize};
use tokio::sync::broadcast;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TraceEvent {
    pub trace_id: String,
    pub model: String,
    pub duration_ms: u64,
    pub status: String,
    pub preview: String,
}

// Global broadcast channel for trace events
lazy_static::lazy_static! {
    static ref TRACE_CHANNEL: broadcast::Sender<TraceEvent> = {
        let (tx, _rx) = broadcast::channel(1000);
        tx
    };
}

pub async fn traces_handler(ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(handle_socket)
}

async fn handle_socket(mut socket: WebSocket) {
    let mut rx = TRACE_CHANNEL.subscribe();

    loop {
        tokio::select! {
            // Receive trace events from broadcast channel
            Ok(trace) = rx.recv() => {
                let msg = Message::Text(serde_json::to_string(&trace).unwrap());
                if socket.send(msg).await.is_err() {
                    break;  // Client disconnected
                }
            }

            // Receive messages from client (e.g., filter updates)
            Some(Ok(Message::Text(filter))) = socket.recv() => {
                // Apply filter (omitted for brevity)
                tracing::info!("Filter applied: {}", filter);
            }

            // Client disconnected
            _ = socket.recv() => {
                break;
            }
        }
    }
}

// Call this when a new trace is created
pub fn publish_trace(trace: TraceEvent) {
    let _ = TRACE_CHANNEL.send(trace);
}
```

---

### 6.5 SSE Implementation

```rust
use axum::response::sse::{Event, KeepAlive, Sse};
use futures::stream::{self, Stream};
use std::time::Duration;

#[derive(Clone, Debug, Serialize)]
pub struct MetricsSnapshot {
    pub timestamp: i64,
    pub requests_per_sec: f64,
    pub tokens_per_sec: u64,
    pub avg_latency_ms: f64,
    pub error_rate: f64,
}

pub async fn metrics_stream() -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let stream = stream::unfold((), |_| async {
        tokio::time::sleep(Duration::from_secs(1)).await;

        let metrics = get_current_metrics().await;  // Fetch from aggregator
        let event = Event::default()
            .json_data(&metrics)
            .unwrap();

        Some((Ok(event), ()))
    });

    Sse::new(stream).keep_alive(KeepAlive::default())
}

async fn get_current_metrics() -> MetricsSnapshot {
    // Query from in-memory aggregator or DB
    MetricsSnapshot {
        timestamp: chrono::Utc::now().timestamp(),
        requests_per_sec: 123.4,
        tokens_per_sec: 45600,
        avg_latency_ms: 245.0,
        error_rate: 0.02,
    }
}
```

---

### 6.6 Data Storage Strategy

**Option 1: In-Memory + TimescaleDB (Recommended)**

```rust
use dashmap::DashMap;
use sqlx::PgPool;

// Hot data (last 1 hour) in memory
pub struct MetricsAggregator {
    // Key: (metric_name, model, timestamp_bucket)
    hot_data: DashMap<String, MetricBucket>,
    db: PgPool,
}

impl MetricsAggregator {
    pub async fn flush_to_db(&self) {
        for entry in self.hot_data.iter() {
            let (key, bucket) = entry.pair();

            sqlx::query!(
                r#"
                INSERT INTO metrics_1s (timestamp, metric_name, model, value, count)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT DO NOTHING
                "#,
                bucket.timestamp,
                bucket.metric_name,
                bucket.model,
                bucket.value,
                bucket.count,
            )
            .execute(&self.db)
            .await
            .unwrap();
        }

        // Clear flushed data
        self.hot_data.retain(|_, bucket| {
            bucket.timestamp > (Utc::now() - Duration::from_secs(3600))
        });
    }
}
```

**TimescaleDB Schema:**

```sql
-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Metrics table (1-second resolution)
CREATE TABLE metrics_1s (
    timestamp    TIMESTAMPTZ NOT NULL,
    metric_name  TEXT NOT NULL,
    model        TEXT NOT NULL,
    value        DOUBLE PRECISION,
    count        BIGINT,
    PRIMARY KEY (timestamp, metric_name, model)
);

-- Convert to hypertable
SELECT create_hypertable('metrics_1s', 'timestamp');

-- Continuous aggregates for downsampling
CREATE MATERIALIZED VIEW metrics_1m
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', timestamp) AS bucket,
    metric_name,
    model,
    avg(value) as avg_value,
    sum(count) as total_count
FROM metrics_1s
GROUP BY bucket, metric_name, model;

-- Retention policy (drop old raw data)
SELECT add_retention_policy('metrics_1s', INTERVAL '1 hour');
```

---

**Option 2: ClickHouse (High Cardinality)**

```sql
CREATE TABLE llm_metrics (
    timestamp DateTime64(3),
    metric_name String,
    model String,
    value Float64,
    attributes Map(String, String),  -- For custom tags
    INDEX idx_model model TYPE bloom_filter GRANULARITY 1
) ENGINE = MergeTree()
ORDER BY (metric_name, model, timestamp)
PARTITION BY toYYYYMM(timestamp)
TTL timestamp + INTERVAL 30 DAY;  -- Auto-delete after 30 days
```

---

## 7. Recommended Technology Stack for MVP

### Final Recommendation

**Architecture: Hybrid (Terminal + Web)**

```
Primary: Ratatui Terminal UI
└─> For developers during active debugging
└─> Fast, lightweight, SSH-friendly
└─> Lives in same repo as Rust backend

Secondary: Svelte Web UI (optional)
└─> For team dashboards, management
└─> Lightweight, fast startup
└─> Deployed separately or served by Axum
```

---

**MVP Tech Stack:**

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Backend** | Rust + Axum + Tokio | High performance, type safety, low latency |
| **Observability** | OpenTelemetry + OTLP | Industry standard, future-proof |
| **Metrics** | Prometheus format | Compatible with Grafana, widely adopted |
| **Traces** | OTLP → Jaeger (optional) | Standard protocol, optional storage |
| **Real-time** | SSE (metrics) + WebSocket (traces) | SSE simpler, WS for interactivity |
| **Terminal UI** | Ratatui + Crossterm | Native Rust, fast, developer-focused |
| **Web UI** | Svelte + Chart.js | Lightweight, fast, excellent DX |
| **Database** | TimescaleDB (PostgreSQL) | Time-series optimized, SQL familiarity |
| **Hot Cache** | DashMap (in-memory) | Lock-free, concurrent HashMap |

---

**Phase 1: Terminal UI Only (Week 1-2)**
- Ratatui dashboard with basic metrics
- Axum server with REST API
- In-memory aggregation (DashMap)
- No database (ephemeral data only)

**Phase 2: Add Persistence (Week 3)**
- TimescaleDB integration
- Historical queries (last 24h, 7d)
- Downsampling strategy

**Phase 3: Add Web UI (Week 4-5)**
- Svelte dashboard
- SSE for metrics
- WebSocket for traces
- Responsive design

**Phase 4: Advanced Features (Week 6+)**
- Alerting (PagerDuty, Slack)
- Flamegraphs
- Anomaly detection
- Custom dashboards

---

## 8. References & Resources

### Documentation
- **Ratatui:** https://ratatui.rs/
- **Axum:** https://docs.rs/axum/latest/axum/
- **OpenTelemetry Rust:** https://opentelemetry.io/docs/languages/rust/
- **Svelte:** https://svelte.dev/docs
- **TimescaleDB:** https://docs.timescale.com/

### Example Projects
- **Bottom (System Monitor):** https://github.com/ClementTsang/bottom
- **kdash (K8s Dashboard):** https://github.com/kdash-rs/kdash
- **OpenLIT:** https://github.com/openlit/openlit
- **Grafana LLM Dashboards:** https://grafana.com/grafana/dashboards/?search=llm

### Observability Standards
- **OpenTelemetry Semantic Conventions:** https://opentelemetry.io/docs/specs/semconv/
- **Prometheus Best Practices:** https://prometheus.io/docs/practices/naming/
- **OTLP Protocol:** https://opentelemetry.io/docs/specs/otlp/

### LLM-Specific Resources
- **Langfuse (LLM Observability):** https://langfuse.com/docs
- **LiteLLM Proxy:** https://docs.litellm.ai/docs/
- **Datadog LLM Observability:** https://docs.datadoghq.com/llm_observability/

---

## Appendix: ASCII Mockups

### A. Terminal Dashboard - Trace Detail View

```
┌──────────────────────────────────────────────────────────────────────┐
│ Trace Detail: trace_abc123                        [E]xport [B]ack    │
├──────────────────────────────────────────────────────────────────────┤
│ Model: gpt-4o              Duration: 1,234ms         Status: OK      │
│ Timestamp: 2025-11-05 10:32:15 UTC                                   │
├──────────────────────────────────────────────────────────────────────┤
│ TIMELINE (Gantt)                                                     │
├──────────────────────────────────────────────────────────────────────┤
│ llm.request              ├───────────────────────────────────────┤   │
│ ├─ tokenize              ├─┤                                         │
│ ├─ prefill               |  ├──────┤                                 │
│ ├─ generate              |        ├──────────────────┤               │
│ └─ detokenize            |                           ├─┤             │
│ ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐│
│ 0ms   100   200   300   400   500   600   700   800   900   1s  1.2s││
│ └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘│
├──────────────────────────────────────────────────────────────────────┤
│ LATENCY BREAKDOWN                                                    │
├──────────────────────────────────────────────────────────────────────┤
│ Tokenize:     12ms   1%  ▓                                           │
│ Prefill:     234ms  19%  ▓▓▓▓▓▓▓▓▓                                  │
│ Generate:    890ms  72%  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │
│ Detokenize:   98ms   8%  ▓▓▓▓                                        │
├──────────────────────────────────────────────────────────────────────┤
│ ATTRIBUTES                                                           │
├──────────────────────────────────────────────────────────────────────┤
│ llm.model_name:          gpt-4o                                      │
│ llm.request.max_tokens:  1000                                        │
│ llm.usage.input_tokens:  150                                         │
│ llm.usage.output_tokens: 890                                         │
│ llm.usage.total_tokens:  1040                                        │
│ llm.cost_usd:            0.0234                                      │
├──────────────────────────────────────────────────────────────────────┤
│ PROMPT (scroll with ↑↓)                                              │
├──────────────────────────────────────────────────────────────────────┤
│ Summarize the following document in 3 bullet points:                │
│                                                                       │
│ [Document content here, showing first 500 characters...]             │
│ ...                                                                   │
├──────────────────────────────────────────────────────────────────────┤
│ RESPONSE                                                             │
├──────────────────────────────────────────────────────────────────────┤
│ - Key finding #1: The analysis reveals...                           │
│ - Key finding #2: Performance improved by...                        │
│ - Key finding #3: Recommendations include...                        │
└──────────────────────────────────────────────────────────────────────┘
```

---

**End of Research Document**

---

## Conclusion

This research provides a comprehensive foundation for building an LLM observability platform with the following key takeaways:

1. **Dual-UI Approach:** Terminal (Ratatui) for developers + Web (Svelte) for teams
2. **Real-time Strategy:** SSE for metrics (simpler) + WebSocket for traces (interactive)
3. **Technology Stack:** Rust + Axum + OpenTelemetry + TimescaleDB
4. **MVP Priorities:** Focus on request rate, latency, tokens, cost, errors first
5. **UX Principles:** Overview-first, drill-down capabilities, clear alerts, fast performance

The recommended stack balances performance, developer experience, and observability best practices while remaining flexible for future extensions.
