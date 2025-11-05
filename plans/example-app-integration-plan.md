# Example App Integration - Implementation Plan

**Document Version:** 1.0
**Date:** 2025-11-05
**Status:** Planning Phase
**Target Completion:** 2-3 weeks
**Commercial Viability:** Enterprise-Grade Reference Implementation

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Business Case & Value Proposition](#business-case--value-proposition)
3. [Application Architecture](#application-architecture)
4. [Use Cases & Scenarios](#use-cases--scenarios)
5. [Technology Stack](#technology-stack)
6. [Implementation Phases](#implementation-phases)
7. [Detailed Component Specifications](#detailed-component-specifications)
8. [Integration Patterns](#integration-patterns)
9. [SDK Development](#sdk-development)
10. [Testing Strategy](#testing-strategy)
11. [Documentation Requirements](#documentation-requirements)
12. [Success Criteria](#success-criteria)
13. [Commercial Deployment Guide](#commercial-deployment-guide)

---

## Executive Summary

### Purpose

Create a **comprehensive, production-ready example application** that demonstrates:
- **Complete LLM Observatory integration** across multiple languages and frameworks
- **Real-world use cases** that enterprises actually deploy
- **Best practices** for LLM observability and cost management
- **SDK usage patterns** for Python, Node.js, and Rust
- **End-to-end monitoring** from request to visualization

### Strategic Goals

1. **Accelerate Adoption**: Reduce time-to-value from weeks to hours
2. **Demonstrate Value**: Show cost savings, performance optimization, quality improvements
3. **Enable Self-Service**: Developers can copy-paste and adapt for their needs
4. **Build Credibility**: Enterprise-grade code that passes security/compliance reviews
5. **Drive Integration**: Reference for partners, customers, and open-source contributors

### Target Audience

- **Enterprise Developers**: Building LLM-powered applications
- **DevOps/Platform Engineers**: Operating LLM infrastructure
- **Product Managers**: Understanding observability value
- **CTOs/Technical Leaders**: Evaluating LLM Observatory for adoption
- **Partners/Integrators**: Building on top of LLM Observatory

### What We're Building

An **"AI Customer Support Platform"** that showcases:

```
┌────────────────────────────────────────────────────────────────┐
│                  AI Customer Support Platform                  │
│           (Realistic Enterprise SaaS Application)              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Frontend (React/TypeScript)                                  │
│  ├─ Customer Chat Interface                                   │
│  ├─ Agent Dashboard                                           │
│  ├─ Analytics Dashboard (LLM Observatory Integration)         │
│  └─ Admin Panel                                               │
│                                                                │
│  Backend APIs (Python FastAPI, Node.js Express, Rust Axum)   │
│  ├─ Chat API (real-time conversations)                       │
│  ├─ Knowledge Base API (RAG implementation)                   │
│  ├─ Ticket Management API                                     │
│  └─ Analytics API                                             │
│                                                                │
│  LLM Processing Layer (Multi-Provider)                        │
│  ├─ OpenAI GPT-4 (primary)                                   │
│  ├─ Anthropic Claude (fallback)                              │
│  ├─ Azure OpenAI (enterprise option)                         │
│  └─ Embedding Models (text-embedding-3)                      │
│                                                                │
│  LLM Observatory Integration                                  │
│  ├─ Python SDK (auto-instrumentation)                        │
│  ├─ Node.js SDK (middleware pattern)                         │
│  ├─ Rust SDK (trait-based)                                   │
│  └─ Direct OTLP (for other languages)                        │
│                                                                │
│  Data Stores                                                   │
│  ├─ PostgreSQL (application data)                            │
│  ├─ Vector DB (Qdrant - for RAG)                            │
│  └─ Redis (caching, sessions)                                │
│                                                                │
│  LLM Observatory Stack                                         │
│  ├─ Collector (OTLP ingestion)                               │
│  ├─ Storage (TimescaleDB)                                    │
│  ├─ API (queries)                                             │
│  └─ Grafana (visualization)                                   │
└────────────────────────────────────────────────────────────────┘
```

**Key Features to Demonstrate:**
- Multi-turn conversations with context
- RAG (Retrieval Augmented Generation) for knowledge base
- Streaming responses
- Function calling / tool use
- Multi-model fallback strategy
- Cost optimization techniques
- Performance monitoring
- Quality assessment
- A/B testing different models
- Error handling and retries

---

## Business Case & Value Proposition

### Problem Statement

Enterprises building LLM applications face critical challenges:

1. **Cost Explosion**: "Our OpenAI bill went from $5K to $50K/month and we don't know why"
2. **Performance Issues**: "Response times increased 300% but we can't identify the cause"
3. **Quality Degradation**: "Users complaining about responses but no way to reproduce"
4. **Vendor Lock-in**: "Can't switch providers without rewriting everything"
5. **Compliance Gaps**: "Audit requires trace of all AI decisions but we have nothing"

### Solution: LLM Observatory

**Observability that pays for itself:**

- **Cost Savings**: Identify and eliminate 30-40% of unnecessary LLM calls
- **Performance**: Reduce P95 latency by 50% through bottleneck identification
- **Quality**: Improve user satisfaction by catching issues before users report
- **Flexibility**: Switch providers in hours, not months
- **Compliance**: Complete audit trail with PII redaction

### ROI Demonstration

**Example Metrics from Demo App:**

| Metric | Without Observatory | With Observatory | Improvement |
|--------|-------------------|------------------|-------------|
| Monthly LLM Cost | $50,000 | $32,000 | 36% reduction |
| Mean Time to Detect (MTTD) | 2 hours | 5 minutes | 96% faster |
| Failed Requests | 3.2% | 0.8% | 75% reduction |
| P95 Latency | 4.5s | 2.1s | 53% faster |
| Context Window Waste | 45% | 12% | 73% reduction |

**Payback Period:** Typically 1-2 months for organizations spending >$10K/month on LLMs

---

## Application Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Users                                    │
│              (Customers, Agents, Administrators)                 │
└─────────────────┬───────────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────────┐
│                    Frontend Layer                                │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌─────────────┐              │
│  │  Customer  │  │   Agent    │  │  Analytics  │              │
│  │    Chat    │  │ Dashboard  │  │  Dashboard  │              │
│  │  (React)   │  │  (React)   │  │   (React)   │              │
│  └────────────┘  └────────────┘  └─────────────┘              │
│         │               │                 │                      │
│         └───────────────┼─────────────────┘                      │
│                         │                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────┐
│                    API Gateway (Optional)                        │
│              Rate Limiting, Auth, Load Balancing                 │
└─────────────────────────┬────────────────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────────────────┐
│                   Application Services                           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Chat API    │  │  Knowledge   │  │  Analytics   │         │
│  │  (Python)    │  │  Base API    │  │     API      │         │
│  │  FastAPI     │  │  (Node.js)   │  │   (Rust)     │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
│         │                  │                  │                  │
│         └──────────────────┼──────────────────┘                  │
│                            │                                     │
└────────────────────────────┼─────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼─────┐     ┌────────▼───────┐   ┌───────▼──────┐
│   LLM SDK   │     │  LLM SDK       │   │   LLM SDK    │
│  (Python)   │     │  (Node.js)     │   │   (Rust)     │
│  Auto-inst. │     │  Middleware    │   │   Trait      │
└───────┬─────┘     └────────┬───────┘   └───────┬──────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼─────────┐  ┌───────▼─────────┐  ┌─────▼────────┐
│   OpenAI API    │  │ Anthropic API   │  │ Azure OpenAI │
│   GPT-4, GPT-3  │  │ Claude 3 Opus   │  │   GPT-4      │
└───────┬─────────┘  └───────┬─────────┘  └─────┬────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │  OTLP Collector   │
                   │  (LLM Observatory)│
                   └─────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼─────────┐  ┌───────▼─────────┐  ┌─────▼────────┐
│  TimescaleDB    │  │     Redis       │  │   Qdrant     │
│  (Traces/Logs)  │  │    (Cache)      │  │  (Vectors)   │
└─────────────────┘  └─────────────────┘  └──────────────┘
```

### Component Responsibilities

#### Frontend Applications

**1. Customer Chat Interface**
- Real-time chat with AI assistant
- Streaming response visualization
- Conversation history
- File upload support
- Feedback collection (👍/👎)

**2. Agent Dashboard**
- Live chat monitoring
- AI suggestion panel
- Escalation workflows
- Performance metrics
- Quality scores

**3. Analytics Dashboard**
- Cost tracking per conversation/user/model
- Performance metrics (latency, throughput)
- Quality metrics (feedback, resolution rate)
- Model comparison (A/B test results)
- Anomaly detection alerts

#### Backend Services

**1. Chat API (Python/FastAPI)**
```python
POST /api/v1/chat/send
POST /api/v1/chat/stream
GET  /api/v1/chat/history/{conversation_id}
POST /api/v1/chat/feedback
```

**Features:**
- Multi-turn conversation management
- Context window optimization
- Streaming responses (SSE)
- Automatic cost tracking
- Quality scoring

**2. Knowledge Base API (Node.js/Express)**
```javascript
POST /api/v1/kb/search        // RAG semantic search
POST /api/v1/kb/documents     // Upload documents
GET  /api/v1/kb/documents     // List documents
POST /api/v1/kb/embed         // Generate embeddings
```

**Features:**
- Document chunking and embedding
- Hybrid search (semantic + keyword)
- Citation tracking
- Relevance scoring

**3. Analytics API (Rust/Axum)**
```rust
GET /api/v1/analytics/costs
GET /api/v1/analytics/performance
GET /api/v1/analytics/quality
GET /api/v1/analytics/models/compare
```

**Features:**
- Real-time metrics aggregation
- Time-series queries to TimescaleDB
- Cost optimization recommendations
- Model performance comparison

#### Data Layer

**PostgreSQL** (Application Data)
- Users, conversations, messages
- Feedback and ratings
- Access control

**Qdrant** (Vector Database)
- Document embeddings
- Semantic search
- Similarity matching

**Redis** (Caching)
- Session management
- Rate limiting
- Recent conversation cache

**TimescaleDB** (LLM Observatory)
- Traces, spans, events
- Metrics, logs
- Continuous aggregates

---

## Use Cases & Scenarios

### Use Case 1: Customer Support Chatbot

**Scenario:** Customer asks about order status

**Flow:**
1. Customer: "Where is my order #12345?"
2. System retrieves order data from knowledge base (RAG)
3. LLM generates contextual response
4. Response streamed to customer
5. **Observatory captures:**
   - Prompt with order context (4,200 tokens)
   - Response generation (850 tokens)
   - Model: GPT-4
   - Cost: $0.18
   - Latency: 2.3s
   - Embedding query: 512 tokens ($0.002)

**Insights Gained:**
- High token usage for simple query (optimization opportunity)
- Latency acceptable but could be improved
- Cost per interaction tracked

### Use Case 2: Document Analysis

**Scenario:** Agent asks AI to summarize customer complaint

**Flow:**
1. Agent uploads 10-page PDF
2. System chunks document (20 chunks)
3. Embeddings generated for all chunks
4. Summary request to LLM with relevant chunks
5. **Observatory captures:**
   - Document processing: 20 embedding calls
   - Summary generation: GPT-4 call
   - Total tokens: 12,500 (input) + 450 (output)
   - Total cost: $0.47
   - Processing time: 8.2s

**Insights Gained:**
- Embedding costs add up for large documents
- Opportunity to cache embeddings
- Processing time dominated by embeddings

### Use Case 3: Multi-Model Fallback

**Scenario:** Primary model (GPT-4) is rate limited

**Flow:**
1. Customer sends message
2. GPT-4 call fails with 429 (rate limit)
3. System automatically falls back to Claude 3
4. Response successful
5. **Observatory captures:**
   - First attempt: GPT-4 (failed, 0 tokens, 0.5s)
   - Second attempt: Claude 3 (success, 3,200 tokens, 1.8s)
   - Cost: $0.11 (Claude cheaper)
   - Total latency: 2.3s (including retry)

**Insights Gained:**
- Fallback strategy working
- Claude actually faster and cheaper for this query
- Consider making Claude primary for certain query types

### Use Case 4: A/B Testing

**Scenario:** Testing GPT-4 vs GPT-3.5-turbo for cost optimization

**Flow:**
1. 50% of conversations use GPT-4
2. 50% of conversations use GPT-3.5-turbo
3. Both collect user feedback (👍/👎)
4. **Observatory captures:**
   - Model A (GPT-4): Avg cost $0.25, 92% positive feedback
   - Model B (GPT-3.5): Avg cost $0.08, 84% positive feedback
   - Decision: Use GPT-3.5 for simple queries (68% cost reduction)

**Insights Gained:**
- 8% quality drop acceptable for 68% cost savings
- Hybrid approach: GPT-3.5 first, escalate to GPT-4 if confidence low

### Use Case 5: Function Calling / Tool Use

**Scenario:** Customer asks to reschedule appointment

**Flow:**
1. Customer: "Can I move my appointment to next Tuesday?"
2. LLM determines tool call needed: `check_availability()`
3. Tool executes, returns available slots
4. LLM generates response with options
5. Customer selects slot
6. LLM calls `reschedule_appointment()` tool
7. **Observatory captures:**
   - Initial message: 1,200 tokens
   - Tool call 1: check_availability (300 tokens)
   - Tool response processing: 800 tokens
   - Tool call 2: reschedule_appointment (250 tokens)
   - Final response: 400 tokens
   - Total: 2,950 tokens, $0.13
   - 3 LLM calls, 6.5s total

**Insights Gained:**
- Function calling adds multiple round trips
- Token usage higher than expected
- Latency acceptable but could be optimized

### Use Case 6: Error Recovery

**Scenario:** LLM returns malformed JSON

**Flow:**
1. System requests structured JSON output
2. LLM returns text instead of JSON
3. Parser fails
4. System retries with explicit JSON schema
5. Second attempt successful
6. **Observatory captures:**
   - Attempt 1: Failed parsing, 2,100 tokens
   - Attempt 2: Success, 2,300 tokens (schema overhead)
   - Total cost: $0.19 (2x expected)
   - User latency: 4.8s (retry delay)

**Insights Gained:**
- JSON schema enforcement reduces errors
- Consider adding schema to initial prompt
- Cost of retries significant

### Use Case 7: Context Window Optimization

**Scenario:** Long conversation reaching context limit

**Flow:**
1. Conversation has 15 messages (18,000 tokens)
2. System detects approaching limit (32K for GPT-4)
3. Summarization triggered for older messages
4. Summary replaces 10 old messages (reduce by 12,000 tokens)
5. New message processed successfully
6. **Observatory captures:**
   - Summarization call: 12,000 input, 800 output
   - Main call: 6,800 tokens (vs 18,000 without summarization)
   - Cost saved: $0.38 per subsequent message
   - Quality maintained: 95% positive feedback

**Insights Gained:**
- Summarization pays for itself after 2-3 messages
- Context window usage tracked proactively
- Opportunity for automatic optimization

### Use Case 8: PII Detection & Redaction

**Scenario:** Customer shares credit card in chat

**Flow:**
1. Customer: "My card is 4532-1234-5678-9010"
2. System detects PII (credit card)
3. Redacts before sending to LLM
4. LLM response asks for secure channel
5. **Observatory captures:**
   - Original message: REDACTED in trace
   - PII detection: credit_card detected
   - Modified prompt: card number replaced with [CARD]
   - Audit log: PII redaction event

**Insights Gained:**
- PII protection working
- No sensitive data sent to LLM provider
- Compliance requirement met

---

## Technology Stack

### Frontend Stack

**Framework:** React 18+ with TypeScript
- **UI Library:** Tailwind CSS + shadcn/ui
- **State Management:** Zustand or Redux Toolkit
- **API Client:** Axios with OpenAPI-generated types
- **Real-time:** Socket.io for streaming
- **Charts:** Recharts for analytics
- **Code Highlighting:** Prism.js for code snippets

**Build Tools:**
- Vite for fast builds
- ESLint + Prettier for code quality
- Playwright for E2E tests

### Backend Stack

#### Python Service (Chat API)

**Framework:** FastAPI 0.100+
- **Why:** Built-in async, OpenAPI docs, type hints
- **LLM Integration:** OpenAI Python SDK, Anthropic SDK
- **Database:** SQLAlchemy 2.0 (async)
- **Caching:** Redis-py
- **Testing:** Pytest with fixtures

**Key Libraries:**
```python
fastapi>=0.100.0
uvicorn[standard]>=0.23.0
sqlalchemy>=2.0.0
redis>=5.0.0
openai>=1.0.0
anthropic>=0.18.0
llm-observatory-sdk  # Our SDK
```

#### Node.js Service (Knowledge Base API)

**Framework:** Express.js with TypeScript
- **Why:** Excellent ecosystem, streaming support
- **Vector DB:** Qdrant client
- **Embeddings:** OpenAI embeddings API
- **PDF Processing:** pdf-parse
- **Testing:** Jest + Supertest

**Key Libraries:**
```json
{
  "express": "^4.18.0",
  "typescript": "^5.0.0",
  "@qdrant/js-client-rest": "^1.8.0",
  "openai": "^4.0.0",
  "pdf-parse": "^1.1.1",
  "llm-observatory-node": "^1.0.0"
}
```

#### Rust Service (Analytics API)

**Framework:** Axum 0.7+
- **Why:** Performance, type safety, async
- **Database:** SQLx for TimescaleDB
- **Serialization:** Serde
- **Testing:** Tokio test

**Key Dependencies:**
```toml
[dependencies]
axum = "0.7"
sqlx = { version = "0.7", features = ["postgres", "runtime-tokio-rustls"] }
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1.0", features = ["full"] }
llm-observatory = { path = "../crates/core" }
```

### Database Stack

**PostgreSQL 16** (Application Data)
- Conversations, messages, users
- Feedback and ratings
- Access control

**TimescaleDB 2.14** (LLM Observatory Data)
- Traces, spans, metrics, logs
- Time-series aggregations
- Retention policies

**Qdrant 1.7+** (Vector Database)
- Document embeddings (1536 dimensions)
- Hybrid search
- Collection per knowledge base

**Redis 7.2** (Caching & Sessions)
- Conversation cache
- Rate limiting
- Session storage

### Infrastructure Stack

**Docker Compose** (Development)
- All services containerized
- Hot reload support
- Consistent environments

**Kubernetes** (Production - Optional)
- Helm charts provided
- Horizontal pod autoscaling
- Service mesh ready (Istio)

**Monitoring**
- Prometheus (metrics)
- Grafana (dashboards)
- Jaeger (distributed tracing)
- Loki (logs)

---

## Implementation Phases

### Phase 1: Foundation & Core Services (Week 1, Days 1-4)

**Goal:** Basic application working with single LLM provider

#### Day 1: Project Setup & Infrastructure

**Tasks:**
1. Initialize monorepo structure
   ```
   llm-observatory-example/
   ├── frontend/          # React app
   ├── services/
   │   ├── chat-api/      # Python FastAPI
   │   ├── kb-api/        # Node.js Express
   │   └── analytics-api/ # Rust Axum
   ├── shared/
   │   ├── types/         # Shared TypeScript types
   │   └── protos/        # Protocol buffers
   ├── docker-compose.yml
   └── docs/
   ```

2. Set up Docker Compose with all services
3. Initialize databases (PostgreSQL, TimescaleDB, Qdrant, Redis)
4. Create basic CI/CD pipeline (GitHub Actions)

**Deliverables:**
- Monorepo structure
- Docker Compose configuration
- All services start successfully
- Database schemas initialized

#### Day 2: Chat API (Python) - Basic Functionality

**Tasks:**
1. Create FastAPI application structure
2. Implement conversation management
   ```python
   POST /api/v1/conversations
   POST /api/v1/conversations/{id}/messages
   GET  /api/v1/conversations/{id}/messages
   ```
3. Integrate OpenAI SDK (GPT-4)
4. Add basic error handling
5. Create PostgreSQL schema

**Deliverables:**
- Working chat API
- OpenAI integration
- Database persistence
- API documentation (Swagger)

#### Day 3: Chat API - LLM Observatory Integration

**Tasks:**
1. Implement Python SDK for LLM Observatory
   ```python
   from llm_observatory import LLMObservatory, instrument_openai

   observatory = LLMObservatory(
       collector_url="http://localhost:4318"
   )

   # Auto-instrument OpenAI
   client = instrument_openai(openai.Client(), observatory)
   ```

2. Add trace creation for each LLM call
3. Capture token usage, cost, latency
4. Send traces to OTLP collector
5. Verify traces appear in Grafana

**Deliverables:**
- Python SDK implementation
- Auto-instrumentation working
- Traces visible in LLM Observatory
- Cost tracking functional

#### Day 4: Frontend - Chat Interface

**Tasks:**
1. Create React chat interface
2. Implement message sending/receiving
3. Add conversation history
4. Style with Tailwind CSS
5. Connect to Chat API

**Deliverables:**
- Working chat UI
- Message list with history
- Send message functionality
- Basic styling

---

### Phase 2: Multi-Model & RAG (Week 1-2, Days 5-8)

#### Day 5: Multi-Provider Support

**Tasks:**
1. Add Anthropic Claude integration
2. Add Azure OpenAI integration
3. Implement provider abstraction layer
   ```python
   class LLMProvider(ABC):
       async def chat(self, messages, **kwargs) -> Response
       async def stream(self, messages, **kwargs) -> AsyncIterator
   ```
4. Add provider selection logic
5. Implement fallback strategy

**Deliverables:**
- 3 providers integrated (OpenAI, Anthropic, Azure)
- Provider abstraction
- Fallback working
- All providers tracked in Observatory

#### Day 6: Knowledge Base API (Node.js) - Setup

**Tasks:**
1. Create Express.js application
2. Set up Qdrant client
3. Implement document upload endpoint
4. Add chunking logic (500 token chunks)
5. Generate embeddings with OpenAI

**Deliverables:**
- Node.js API running
- Document upload working
- Qdrant integration
- Embeddings generated

#### Day 7: RAG Implementation

**Tasks:**
1. Implement semantic search
   ```typescript
   POST /api/v1/kb/search
   {
     "query": "how to reset password",
     "limit": 5,
     "threshold": 0.7
   }
   ```
2. Add hybrid search (semantic + keyword)
3. Implement relevance scoring
4. Add citation tracking
5. Integrate with Chat API

**Deliverables:**
- Semantic search working
- RAG pipeline functional
- Citations returned
- Node.js SDK integrated

#### Day 8: Streaming Responses

**Tasks:**
1. Implement SSE (Server-Sent Events) endpoint
   ```python
   GET /api/v1/conversations/{id}/stream
   ```
2. Add streaming support in Python SDK
3. Update frontend for streaming
4. Add "typing" indicator
5. Track streaming metrics in Observatory

**Deliverables:**
- Streaming responses working
- Real-time UI updates
- Streaming metrics captured

---

### Phase 3: Analytics & Optimization (Week 2, Days 9-11)

#### Day 9: Analytics API (Rust) - Setup

**Tasks:**
1. Create Axum application
2. Connect to TimescaleDB
3. Implement cost analytics endpoint
   ```rust
   GET /api/v1/analytics/costs?start=...&end=...
   ```
4. Add performance metrics endpoint
5. Implement model comparison

**Deliverables:**
- Rust API running
- TimescaleDB queries working
- Cost analytics functional
- Performance metrics available

#### Day 10: Analytics Dashboard (Frontend)

**Tasks:**
1. Create analytics page in React
2. Add cost charts (daily, by model, by user)
3. Add performance charts (latency distribution, throughput)
4. Implement model comparison table
5. Add real-time updates

**Deliverables:**
- Analytics dashboard UI
- Charts rendering data
- Real-time updates
- Responsive design

#### Day 11: Cost Optimization Features

**Tasks:**
1. Implement context window tracking
   ```python
   def optimize_context(messages: List[Message]) -> List[Message]:
       if total_tokens(messages) > threshold:
           return summarize_old_messages(messages)
       return messages
   ```
2. Add caching layer (Redis)
3. Implement prompt compression
4. Add token usage warnings
5. Create optimization recommendations

**Deliverables:**
- Context optimization working
- Caching reducing costs
- Recommendations displayed
- Token savings tracked

---

### Phase 4: Advanced Features (Week 2-3, Days 12-15)

#### Day 12: Function Calling / Tool Use

**Tasks:**
1. Define tools/functions
   ```python
   tools = [
       {
           "name": "get_order_status",
           "description": "Get order status by ID",
           "parameters": {
               "order_id": {"type": "string"}
           }
       }
   ]
   ```
2. Implement tool execution framework
3. Add tool call tracking in Observatory
4. Test multi-step tool use
5. Add error handling for tools

**Deliverables:**
- Function calling working
- Tools tracked separately
- Multi-step workflows functional
- Error handling robust

#### Day 13: A/B Testing Framework

**Tasks:**
1. Implement experiment framework
   ```python
   experiment = Experiment(
       name="gpt4_vs_gpt35",
       variants=["gpt-4", "gpt-3.5-turbo"],
       traffic_split=[0.5, 0.5]
   )
   ```
2. Add user assignment (deterministic)
3. Track metrics per variant
4. Implement statistical significance tests
5. Create experiment dashboard

**Deliverables:**
- A/B testing framework
- Variant assignment working
- Metrics tracked per variant
- Dashboard showing results

#### Day 14: Quality & Feedback

**Tasks:**
1. Add feedback buttons (👍/👎)
2. Implement quality scoring
3. Add flag for review
4. Create agent escalation flow
5. Track quality metrics in Observatory

**Deliverables:**
- Feedback collection working
- Quality scores calculated
- Escalation functional
- Quality trends visible

#### Day 15: Error Handling & Resilience

**Tasks:**
1. Implement retry logic with exponential backoff
2. Add circuit breaker pattern
3. Implement graceful degradation
4. Add error tracking to Observatory
5. Create error dashboard

**Deliverables:**
- Robust error handling
- Circuit breakers working
- Graceful degradation
- Error metrics tracked

---

### Phase 5: Production Readiness (Week 3, Days 16-18)

#### Day 16: Security & Compliance

**Tasks:**
1. Implement PII detection and redaction
   ```python
   def detect_pii(text: str) -> List[PIIEntity]:
       # Detect credit cards, SSNs, emails, etc.
       pass

   def redact_pii(text: str) -> str:
       # Replace PII with placeholders
       pass
   ```
2. Add audit logging
3. Implement RBAC (Role-Based Access Control)
4. Add rate limiting
5. Enable HTTPS/TLS

**Deliverables:**
- PII detection working
- Audit logs captured
- RBAC implemented
- Rate limiting enforced
- TLS configured

#### Day 17: Testing & Quality Assurance

**Tasks:**
1. Write unit tests (80%+ coverage)
2. Create integration tests
3. Add E2E tests with Playwright
4. Performance testing with k6
5. Security scanning (OWASP)

**Deliverables:**
- Comprehensive test suite
- >80% code coverage
- E2E tests passing
- Performance benchmarks met
- Security issues resolved

#### Day 18: Deployment & Operations

**Tasks:**
1. Create Kubernetes manifests (optional)
2. Set up production Docker Compose
3. Create deployment guide
4. Add monitoring dashboards
5. Create runbook for operations

**Deliverables:**
- Deployment artifacts
- Operations documentation
- Monitoring configured
- Runbook complete

---

### Phase 6: Documentation & Polish (Week 3, Days 19-21)

#### Day 19: Developer Documentation

**Tasks:**
1. Write comprehensive README
2. Create architecture documentation
3. Write API documentation
4. Create SDK guides (Python, Node.js, Rust)
5. Add code examples

**Deliverables:**
- Complete README
- Architecture diagrams
- API reference
- SDK documentation
- Example code

#### Day 20: User Documentation

**Tasks:**
1. Create user guide
2. Write tutorial (0-60 in 15 minutes)
3. Create video walkthrough
4. Add troubleshooting guide
5. Create FAQ

**Deliverables:**
- User guide
- Tutorial
- Video demonstration
- Troubleshooting docs
- FAQ

#### Day 21: Final Polish & Launch

**Tasks:**
1. UI/UX polish
2. Performance optimization
3. Bug fixes
4. Final testing
5. Launch preparation

**Deliverables:**
- Production-ready application
- All bugs resolved
- Performance optimized
- Launch announcement ready

---

## Detailed Component Specifications

### Python SDK (llm-observatory-python)

#### Auto-Instrumentation

```python
# llm_observatory/instrument.py

from typing import Optional, Dict, Any
import openai
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

class LLMObservatory:
    """Main SDK class for LLM Observatory integration."""

    def __init__(
        self,
        collector_url: str = "http://localhost:4318",
        service_name: str = "my-app",
        environment: str = "development",
        api_key: Optional[str] = None,
    ):
        self.collector_url = collector_url
        self.service_name = service_name
        self.environment = environment
        self.api_key = api_key

        # Initialize OpenTelemetry
        self._setup_tracing()

    def _setup_tracing(self):
        """Configure OpenTelemetry tracing."""
        provider = TracerProvider()
        exporter = OTLPSpanExporter(endpoint=self.collector_url)
        processor = BatchSpanProcessor(exporter)
        provider.add_span_processor(processor)
        trace.set_tracer_provider(provider)

def instrument_openai(
    client: openai.Client,
    observatory: LLMObservatory,
) -> openai.Client:
    """Instrument OpenAI client with automatic tracing."""

    original_create = client.chat.completions.create

    def traced_create(*args, **kwargs):
        tracer = trace.get_tracer(__name__)

        with tracer.start_as_current_span("llm.chat.completions") as span:
            # Extract parameters
            messages = kwargs.get("messages", [])
            model = kwargs.get("model", "unknown")

            # Set span attributes
            span.set_attribute("llm.provider", "openai")
            span.set_attribute("llm.model", model)
            span.set_attribute("llm.message_count", len(messages))

            # Calculate input tokens (approximation)
            input_tokens = sum(len(m["content"].split()) * 1.3 for m in messages)
            span.set_attribute("llm.input_tokens", int(input_tokens))

            try:
                # Call original method
                response = original_create(*args, **kwargs)

                # Extract response details
                output_tokens = response.usage.completion_tokens
                total_tokens = response.usage.total_tokens

                span.set_attribute("llm.output_tokens", output_tokens)
                span.set_attribute("llm.total_tokens", total_tokens)

                # Calculate cost
                cost = calculate_cost(model, total_tokens, output_tokens)
                span.set_attribute("llm.cost_usd", cost)

                span.set_status(trace.Status(trace.StatusCode.OK))

                return response

            except Exception as e:
                span.set_status(
                    trace.Status(trace.StatusCode.ERROR, str(e))
                )
                span.record_exception(e)
                raise

    # Replace method
    client.chat.completions.create = traced_create
    return client

def calculate_cost(model: str, input_tokens: int, output_tokens: int) -> float:
    """Calculate cost based on model pricing."""
    pricing = {
        "gpt-4": {"input": 0.03, "output": 0.06},  # per 1K tokens
        "gpt-3.5-turbo": {"input": 0.0015, "output": 0.002},
        "claude-3-opus": {"input": 0.015, "output": 0.075},
        "claude-3-sonnet": {"input": 0.003, "output": 0.015},
    }

    if model not in pricing:
        return 0.0

    input_cost = (input_tokens / 1000) * pricing[model]["input"]
    output_cost = (output_tokens / 1000) * pricing[model]["output"]

    return input_cost + output_cost
```

#### Usage Example

```python
# main.py

from llm_observatory import LLMObservatory, instrument_openai
import openai

# Initialize Observatory
observatory = LLMObservatory(
    collector_url="http://localhost:4318",
    service_name="customer-support-bot",
    environment="production",
)

# Create instrumented OpenAI client
client = openai.Client(api_key="...")
client = instrument_openai(client, observatory)

# Use as normal - tracing happens automatically
response = client.chat.completions.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is the weather today?"},
    ]
)

# Trace is automatically sent to LLM Observatory!
print(response.choices[0].message.content)
```

---

### Node.js SDK (llm-observatory-node)

#### Middleware Pattern

```typescript
// src/index.ts

import { trace, context, SpanStatusCode } from '@opentelemetry/api';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
import OpenAI from 'openai';

export interface ObservatoryConfig {
  collectorUrl?: string;
  serviceName?: string;
  environment?: string;
  apiKey?: string;
}

export class LLMObservatory {
  private tracer: any;

  constructor(config: ObservatoryConfig = {}) {
    const {
      collectorUrl = 'http://localhost:4318/v1/traces',
      serviceName = 'my-app',
      environment = 'development',
    } = config;

    // Initialize OpenTelemetry
    const provider = new NodeTracerProvider({
      resource: new Resource({
        'service.name': serviceName,
        'deployment.environment': environment,
      }),
    });

    const exporter = new OTLPTraceExporter({
      url: collectorUrl,
    });

    provider.addSpanProcessor(new BatchSpanProcessor(exporter));
    provider.register();

    this.tracer = trace.getTracer('llm-observatory');
  }

  instrumentOpenAI(client: OpenAI): OpenAI {
    const originalCreate = client.chat.completions.create.bind(client.chat.completions);

    client.chat.completions.create = async (params: any) => {
      return await this.tracer.startActiveSpan(
        'llm.chat.completions',
        async (span: any) => {
          try {
            // Set attributes
            span.setAttribute('llm.provider', 'openai');
            span.setAttribute('llm.model', params.model);
            span.setAttribute('llm.message_count', params.messages.length);

            // Estimate input tokens
            const inputTokens = this.estimateTokens(
              params.messages.map((m: any) => m.content).join(' ')
            );
            span.setAttribute('llm.input_tokens', inputTokens);

            // Call API
            const response = await originalCreate(params);

            // Extract usage
            if (response.usage) {
              span.setAttribute('llm.output_tokens', response.usage.completion_tokens);
              span.setAttribute('llm.total_tokens', response.usage.total_tokens);

              // Calculate cost
              const cost = this.calculateCost(
                params.model,
                response.usage.prompt_tokens,
                response.usage.completion_tokens
              );
              span.setAttribute('llm.cost_usd', cost);
            }

            span.setStatus({ code: SpanStatusCode.OK });
            return response;

          } catch (error: any) {
            span.setStatus({
              code: SpanStatusCode.ERROR,
              message: error.message,
            });
            span.recordException(error);
            throw error;

          } finally {
            span.end();
          }
        }
      );
    };

    return client;
  }

  private estimateTokens(text: string): number {
    // Rough estimation: 1 token ≈ 4 characters
    return Math.ceil(text.length / 4);
  }

  private calculateCost(
    model: string,
    inputTokens: number,
    outputTokens: number
  ): number {
    const pricing: Record<string, { input: number; output: number }> = {
      'gpt-4': { input: 0.03, output: 0.06 },
      'gpt-3.5-turbo': { input: 0.0015, output: 0.002 },
    };

    if (!pricing[model]) return 0;

    return (
      (inputTokens / 1000) * pricing[model].input +
      (outputTokens / 1000) * pricing[model].output
    );
  }
}
```

#### Usage Example

```typescript
// app.ts

import OpenAI from 'openai';
import { LLMObservatory } from 'llm-observatory-node';

// Initialize Observatory
const observatory = new LLMObservatory({
  collectorUrl: 'http://localhost:4318/v1/traces',
  serviceName: 'kb-api',
  environment: 'production',
});

// Create instrumented OpenAI client
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const instrumentedClient = observatory.instrumentOpenAI(openai);

// Use as normal
async function generateEmbedding(text: string) {
  const response = await instrumentedClient.embeddings.create({
    model: 'text-embedding-3-small',
    input: text,
  });

  return response.data[0].embedding;
}

// Automatically tracked in LLM Observatory!
```

---

### Rust SDK (llm-observatory-rust)

#### Trait-Based Approach

```rust
// src/lib.rs

use async_trait::async_trait;
use opentelemetry::{
    global, trace::{Span, Tracer, TracerProvider as _},
    KeyValue,
};
use opentelemetry_sdk::{
    trace::{TracerProvider, Config},
    Resource,
};
use opentelemetry_otlp::WithExportConfig;

pub struct LLMObservatory {
    tracer: Box<dyn Tracer + Send + Sync>,
}

impl LLMObservatory {
    pub fn new(collector_url: &str, service_name: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let exporter = opentelemetry_otlp::new_exporter()
            .tonic()
            .with_endpoint(collector_url);

        let provider = TracerProvider::builder()
            .with_batch_exporter(exporter.build_span_exporter()?, tokio::spawn)
            .with_config(
                Config::default().with_resource(Resource::new(vec![
                    KeyValue::new("service.name", service_name.to_string()),
                ]))
            )
            .build();

        global::set_tracer_provider(provider.clone());

        Ok(Self {
            tracer: Box::new(provider.tracer("llm-observatory")),
        })
    }
}

/// Trait for LLM providers with automatic instrumentation
#[async_trait]
pub trait InstrumentedLLM {
    async fn chat_completion(
        &self,
        messages: Vec<ChatMessage>,
        model: &str,
    ) -> Result<ChatResponse, Box<dyn std::error::Error>>;
}

pub struct ChatMessage {
    pub role: String,
    pub content: String,
}

pub struct ChatResponse {
    pub content: String,
    pub usage: TokenUsage,
}

pub struct TokenUsage {
    pub prompt_tokens: u32,
    pub completion_tokens: u32,
    pub total_tokens: u32,
}

/// OpenAI client with instrumentation
pub struct InstrumentedOpenAI {
    client: reqwest::Client,
    api_key: String,
    observatory: LLMObservatory,
}

impl InstrumentedOpenAI {
    pub fn new(api_key: String, observatory: LLMObservatory) -> Self {
        Self {
            client: reqwest::Client::new(),
            api_key,
            observatory,
        }
    }
}

#[async_trait]
impl InstrumentedLLM for InstrumentedOpenAI {
    async fn chat_completion(
        &self,
        messages: Vec<ChatMessage>,
        model: &str,
    ) -> Result<ChatResponse, Box<dyn std::error::Error>> {
        let mut span = self.observatory.tracer.start("llm.chat.completions");

        // Set attributes
        span.set_attribute(KeyValue::new("llm.provider", "openai"));
        span.set_attribute(KeyValue::new("llm.model", model.to_string()));
        span.set_attribute(KeyValue::new("llm.message_count", messages.len() as i64));

        // Make API call
        let request_body = serde_json::json!({
            "model": model,
            "messages": messages.iter().map(|m| {
                serde_json::json!({
                    "role": m.role,
                    "content": m.content,
                })
            }).collect::<Vec<_>>(),
        });

        let response = self.client
            .post("https://api.openai.com/v1/chat/completions")
            .header("Authorization", format!("Bearer {}", self.api_key))
            .json(&request_body)
            .send()
            .await?;

        let response_json: serde_json::Value = response.json().await?;

        // Extract usage
        let usage = &response_json["usage"];
        let prompt_tokens = usage["prompt_tokens"].as_u64().unwrap_or(0) as u32;
        let completion_tokens = usage["completion_tokens"].as_u64().unwrap_or(0) as u32;
        let total_tokens = usage["total_tokens"].as_u64().unwrap_or(0) as u32;

        span.set_attribute(KeyValue::new("llm.input_tokens", prompt_tokens as i64));
        span.set_attribute(KeyValue::new("llm.output_tokens", completion_tokens as i64));
        span.set_attribute(KeyValue::new("llm.total_tokens", total_tokens as i64));

        // Calculate cost
        let cost = calculate_cost(model, prompt_tokens, completion_tokens);
        span.set_attribute(KeyValue::new("llm.cost_usd", cost));

        span.end();

        Ok(ChatResponse {
            content: response_json["choices"][0]["message"]["content"]
                .as_str()
                .unwrap_or("")
                .to_string(),
            usage: TokenUsage {
                prompt_tokens,
                completion_tokens,
                total_tokens,
            },
        })
    }
}

fn calculate_cost(model: &str, input_tokens: u32, output_tokens: u32) -> f64 {
    let pricing = match model {
        "gpt-4" => (0.03, 0.06),
        "gpt-3.5-turbo" => (0.0015, 0.002),
        _ => return 0.0,
    };

    ((input_tokens as f64 / 1000.0) * pricing.0) +
    ((output_tokens as f64 / 1000.0) * pricing.1)
}
```

#### Usage Example

```rust
// main.rs

use llm_observatory::{LLMObservatory, InstrumentedOpenAI, InstrumentedLLM, ChatMessage};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize Observatory
    let observatory = LLMObservatory::new(
        "http://localhost:4317",
        "analytics-api",
    )?;

    // Create instrumented OpenAI client
    let api_key = std::env::var("OPENAI_API_KEY")?;
    let client = InstrumentedOpenAI::new(api_key, observatory);

    // Use as normal
    let messages = vec![
        ChatMessage {
            role: "system".to_string(),
            content: "You are a helpful assistant.".to_string(),
        },
        ChatMessage {
            role: "user".to_string(),
            content: "Hello!".to_string(),
        },
    ];

    let response = client.chat_completion(messages, "gpt-4").await?;

    println!("Response: {}", response.content);
    println!("Tokens used: {}", response.usage.total_tokens);

    Ok(())
}
```

---

## Integration Patterns

### Pattern 1: Direct SDK Integration

**When to use:** New applications, full control desired

```python
# Simple, direct integration
from llm_observatory import LLMObservatory, instrument_openai

observatory = LLMObservatory(collector_url="...")
client = instrument_openai(openai.Client(), observatory)
```

**Pros:**
- Simple setup
- Full control
- Minimal overhead

**Cons:**
- Requires code changes
- Must integrate in each service

---

### Pattern 2: Middleware/Wrapper Pattern

**When to use:** Existing codebase, minimal changes desired

```python
# Transparent wrapper
class ObservedLLMClient:
    def __init__(self, inner_client, observatory):
        self.inner = inner_client
        self.observatory = observatory

    def __getattr__(self, name):
        attr = getattr(self.inner, name)
        if callable(attr):
            return self._wrap_method(attr, name)
        return attr

    def _wrap_method(self, method, name):
        def wrapper(*args, **kwargs):
            with self.observatory.trace(name):
                return method(*args, **kwargs)
        return wrapper

# Use existing code
client = ObservedLLMClient(openai.Client(), observatory)
# No other code changes needed!
```

**Pros:**
- Minimal code changes
- Works with existing code
- Transparent to application

**Cons:**
- May miss some context
- Less fine-grained control

---

### Pattern 3: Decorator Pattern

**When to use:** Selective instrumentation, function-level control

```python
from llm_observatory import observe_llm

@observe_llm(model="gpt-4", provider="openai")
async def generate_response(prompt: str) -> str:
    response = await openai_client.chat.completions.create(
        model="gpt-4",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content

# Automatically tracked!
response = await generate_response("Hello")
```

**Pros:**
- Fine-grained control
- Explicit instrumentation
- Clear intent

**Cons:**
- More decorators needed
- Potential for missing calls

---

### Pattern 4: Context Manager Pattern

**When to use:** Complex workflows, manual control

```python
from llm_observatory import LLMObservatory

observatory = LLMObservatory(...)

async def process_conversation(messages):
    with observatory.conversation("customer-support") as conv:
        # Step 1: Semantic search
        with conv.span("search") as span:
            results = await search_knowledge_base(messages[-1])
            span.set_attribute("results_count", len(results))

        # Step 2: Generate response
        with conv.span("generate") as span:
            response = await llm_client.generate(
                messages + [{"role": "system", "content": context}]
            )
            span.set_attribute("model", "gpt-4")
            span.set_attribute("tokens", response.usage.total_tokens)

        # Step 3: Post-process
        with conv.span("post-process") as span:
            final = await format_response(response)

    return final
```

**Pros:**
- Maximum control
- Rich context
- Hierarchical spans

**Cons:**
- More verbose
- Manual management

---

### Pattern 5: Proxy Pattern (API Gateway)

**When to use:** Centralized control, no code changes

```yaml
# Kong/Envoy configuration
plugins:
  - name: llm-observatory
    config:
      collector_url: http://collector:4318
      sample_rate: 1.0
      capture_request: true
      capture_response: true
      redact_pii: true
```

**Pros:**
- Zero code changes
- Centralized configuration
- Works with any language

**Cons:**
- Less context
- Additional infrastructure
- Performance overhead

---

## Testing Strategy

### Unit Tests

**Python (pytest)**
```python
# tests/test_chat_api.py

import pytest
from fastapi.testclient import TestClient
from app.main import app

@pytest.fixture
def client():
    return TestClient(app)

@pytest.fixture
def mock_openai(monkeypatch):
    class MockResponse:
        usage = type('obj', (object,), {
            'prompt_tokens': 100,
            'completion_tokens': 50,
            'total_tokens': 150
        })
        choices = [
            type('obj', (object,), {
                'message': type('obj', (object,), {
                    'content': 'Test response'
                })
            })
        ]

    def mock_create(*args, **kwargs):
        return MockResponse()

    monkeypatch.setattr("openai.Client.chat.completions.create", mock_create)

def test_send_message(client, mock_openai):
    response = client.post(
        "/api/v1/conversations/123/messages",
        json={"content": "Hello"}
    )

    assert response.status_code == 200
    assert response.json()["content"] == "Test response"
    assert response.json()["tokens_used"] == 150
```

**Node.js (Jest)**
```typescript
// tests/kb-api.test.ts

import request from 'supertest';
import { app } from '../src/app';

describe('Knowledge Base API', () => {
  it('should search documents', async () => {
    const response = await request(app)
      .post('/api/v1/kb/search')
      .send({ query: 'test query', limit: 5 })
      .expect(200);

    expect(response.body.results).toHaveLength(5);
    expect(response.body.results[0]).toHaveProperty('content');
    expect(response.body.results[0]).toHaveProperty('score');
  });
});
```

**Rust (tokio-test)**
```rust
// tests/analytics_api.rs

#[tokio::test]
async fn test_cost_analytics() {
    let app = create_test_app().await;

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/analytics/costs?start=2024-01-01&end=2024-01-31")
                .body(Body::empty())
                .unwrap()
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = hyper::body::to_bytes(response.into_body()).await.unwrap();
    let json: serde_json::Value = serde_json::from_slice(&body).unwrap();

    assert!(json["total_cost"].as_f64().unwrap() > 0.0);
}
```

### Integration Tests

**End-to-End Conversation Test**
```python
# tests/integration/test_conversation_e2e.py

import pytest
import asyncio
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_full_conversation_flow():
    async with AsyncClient(base_url="http://localhost:8000") as client:
        # 1. Create conversation
        response = await client.post("/api/v1/conversations")
        assert response.status_code == 201
        conv_id = response.json()["id"]

        # 2. Send message
        response = await client.post(
            f"/api/v1/conversations/{conv_id}/messages",
            json={"content": "What is your return policy?"}
        )
        assert response.status_code == 200
        message = response.json()

        # 3. Verify response
        assert message["content"] != ""
        assert message["tokens_used"] > 0
        assert message["cost_usd"] > 0

        # 4. Wait for trace to be ingested
        await asyncio.sleep(2)

        # 5. Query LLM Observatory
        response = await client.get(
            f"http://localhost:8080/api/v1/traces?conversation_id={conv_id}"
        )
        assert response.status_code == 200
        traces = response.json()["traces"]

        # 6. Verify trace data
        assert len(traces) > 0
        trace = traces[0]
        assert trace["provider"] in ["openai", "anthropic"]
        assert trace["model"] != ""
        assert trace["total_tokens"] > 0
        assert trace["cost_usd"] > 0
```

### Performance Tests (k6)

```javascript
// tests/performance/load_test.js

import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 10 },   // Ramp up
    { duration: '1m', target: 50 },    // Sustain
    { duration: '30s', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% under 2s
    http_req_failed: ['rate<0.01'],     // Less than 1% error
  },
};

export default function() {
  // Send message
  const payload = JSON.stringify({
    content: 'What is your shipping policy?'
  });

  const response = http.post(
    'http://localhost:8000/api/v1/conversations/test-123/messages',
    payload,
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'status is 200': (r) => r.status === 200,
    'response has content': (r) => r.json('content') !== '',
    'response time < 2s': (r) => r.timings.duration < 2000,
  });

  sleep(1);
}
```

### E2E Tests (Playwright)

```typescript
// tests/e2e/chat.spec.ts

import { test, expect } from '@playwright/test';

test('customer can send message and receive response', async ({ page }) => {
  // Navigate to chat
  await page.goto('http://localhost:3000/chat');

  // Type message
  await page.fill('[data-testid="message-input"]', 'Hello, I need help');
  await page.click('[data-testid="send-button"]');

  // Wait for response
  await page.waitForSelector('[data-testid="assistant-message"]', {
    timeout: 10000
  });

  // Verify response
  const response = await page.textContent('[data-testid="assistant-message"]');
  expect(response).not.toBe('');

  // Verify cost is shown
  const cost = await page.textContent('[data-testid="message-cost"]');
  expect(cost).toMatch(/\$\d+\.\d+/);
});

test('analytics dashboard shows cost chart', async ({ page }) => {
  await page.goto('http://localhost:3000/analytics');

  // Wait for chart to load
  await page.waitForSelector('[data-testid="cost-chart"]');

  // Verify chart has data
  const chartData = await page.evaluate(() => {
    const chart = document.querySelector('[data-testid="cost-chart"]');
    return chart?.querySelectorAll('.recharts-bar').length;
  });

  expect(chartData).toBeGreaterThan(0);
});
```

---

## Documentation Requirements

### 1. README.md (Main Entry Point)

```markdown
# AI Customer Support Platform - LLM Observatory Integration Example

A production-ready example application demonstrating enterprise-grade LLM observability.

## Features

- 🤖 Multi-provider LLM support (OpenAI, Anthropic, Azure OpenAI)
- 📊 Complete cost tracking and optimization
- 🔍 RAG-powered knowledge base
- 📈 Real-time analytics dashboard
- 🔄 Automatic retry and fallback
- 🧪 A/B testing framework
- 🔒 PII detection and redaction
- 📱 Responsive web interface

## Quick Start (5 minutes)

### Prerequisites
- Docker & Docker Compose
- Node.js 18+ (for local development)
- Python 3.11+ (for local development)
- Rust 1.75+ (for local development)

### Run with Docker

\`\`\`bash
# Clone repository
git clone https://github.com/llm-observatory/example-app
cd example-app

# Copy environment configuration
cp .env.example .env

# Add your API keys to .env
nano .env

# Start all services
docker-compose up -d

# Wait for services to be ready (~30 seconds)
docker-compose ps

# Open application
open http://localhost:3000
\`\`\`

That's it! The application is now running with full LLM Observatory integration.

## Architecture

[Architecture diagram]

## Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [API Documentation](docs/API.md)
- [SDK Guides](docs/SDK.md)
  - [Python SDK](docs/sdk/PYTHON.md)
  - [Node.js SDK](docs/sdk/NODEJS.md)
  - [Rust SDK](docs/sdk/RUST.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Cost Optimization](docs/COST_OPTIMIZATION.md)

## Use Cases Demonstrated

1. **Customer Support Chatbot**: Multi-turn conversations with context
2. **RAG Knowledge Base**: Document search and retrieval
3. **Multi-Model Fallback**: Automatic provider switching
4. **A/B Testing**: Compare model performance
5. **Function Calling**: Tool use and execution
6. **Streaming Responses**: Real-time output
7. **Cost Optimization**: Context management and caching
8. **Quality Monitoring**: Feedback and scoring

## Technologies Used

- **Frontend**: React, TypeScript, Tailwind CSS
- **Backend**: Python (FastAPI), Node.js (Express), Rust (Axum)
- **LLMs**: OpenAI, Anthropic, Azure OpenAI
- **Databases**: PostgreSQL, TimescaleDB, Qdrant, Redis
- **Observability**: LLM Observatory, Grafana, Prometheus

## License

Apache 2.0
\`\`\`

---

### 2. SDK Documentation

#### Python SDK Guide

```markdown
# Python SDK - LLM Observatory

Complete guide for instrumenting Python applications.

## Installation

\`\`\`bash
pip install llm-observatory-python
\`\`\`

## Quick Start

### Auto-Instrumentation (Recommended)

\`\`\`python
from llm_observatory import LLMObservatory, instrument_openai
import openai

# Initialize
observatory = LLMObservatory(
    collector_url="http://localhost:4318",
    service_name="my-app"
)

# Instrument OpenAI client
client = openai.Client(api_key="...")
client = instrument_openai(client, observatory)

# Use normally - automatic tracing!
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello"}]
)
\`\`\`

### Manual Instrumentation

\`\`\`python
from llm_observatory import LLMObservatory

observatory = LLMObservatory(...)

with observatory.trace("llm.completion") as span:
    span.set_attribute("llm.provider", "openai")
    span.set_attribute("llm.model", "gpt-4")

    response = make_llm_call()

    span.set_attribute("llm.tokens", response.usage.total_tokens)
    span.set_attribute("llm.cost", calculate_cost(response))
\`\`\`

## Advanced Features

### Streaming Support

\`\`\`python
async for chunk in client.chat.completions.create(
    model="gpt-4",
    messages=[...],
    stream=True
):
    print(chunk.choices[0].delta.content)
# Automatically tracked with streaming metrics!
\`\`\`

### Custom Attributes

\`\`\`python
with observatory.trace("llm.rag") as span:
    span.set_attribute("user_id", user.id)
    span.set_attribute("conversation_id", conv.id)
    span.set_attribute("query_type", "support")
    # ... your code ...
\`\`\`

### Cost Optimization

\`\`\`python
from llm_observatory.optimizers import ContextWindowOptimizer

optimizer = ContextWindowOptimizer(max_tokens=8000)
optimized_messages = optimizer.optimize(messages)
# Summarizes old messages when approaching limit
\`\`\`

## Configuration

\`\`\`python
observatory = LLMObservatory(
    collector_url="http://localhost:4318",
    service_name="my-app",
    environment="production",

    # Sampling
    sample_rate=1.0,  # 100% sampling

    # Batching
    batch_size=100,
    batch_timeout_ms=1000,

    # PII Redaction
    redact_pii=True,
    pii_patterns=["credit_card", "ssn", "email"],

    # Cost Tracking
    track_costs=True,
    cost_currency="USD",
)
\`\`\`

## Best Practices

1. **Initialize once**: Create Observatory instance at app startup
2. **Use auto-instrumentation**: Less code, automatic updates
3. **Add context**: Include user_id, conversation_id for filtering
4. **Handle errors**: Wrap LLM calls in try/except
5. **Monitor costs**: Set up alerts for unusual spending

## Troubleshooting

### Traces not appearing?

1. Check collector is reachable: `curl http://localhost:4318`
2. Verify environment variables: `echo $OTEL_EXPORTER_OTLP_ENDPOINT`
3. Enable debug logging: `observatory.set_log_level("DEBUG")`

### High latency?

1. Increase batch size: `batch_size=500`
2. Increase timeout: `batch_timeout_ms=5000`
3. Use async export: `async_export=True`
\`\`\`

---

## Success Criteria

### Functional Requirements ✅

1. **Application Functionality**
   - All 8 use cases working end-to-end
   - Multi-provider support (OpenAI, Anthropic, Azure)
   - RAG implementation functional
   - Streaming responses working
   - Function calling operational

2. **LLM Observatory Integration**
   - All LLM calls traced automatically
   - Cost tracking accurate (<1% error)
   - Performance metrics captured
   - Quality scores calculated
   - Traces visible in Grafana

3. **SDK Functionality**
   - Python SDK: Auto-instrumentation working
   - Node.js SDK: Middleware functional
   - Rust SDK: Trait-based approach operational
   - All SDKs capture: model, tokens, cost, latency

### Performance Requirements ✅

1. **Application Performance**
   - P95 response time < 3s (including LLM call)
   - Support 100 concurrent users
   - Handle 1000 messages/minute

2. **Observatory Overhead**
   - Instrumentation overhead < 5ms per call
   - No dropped traces under normal load
   - Batch processing < 1s lag

### Quality Requirements ✅

1. **Code Quality**
   - 80%+ test coverage
   - All tests passing
   - Type-safe (TypeScript, Rust, Python type hints)
   - Linting passing (ESLint, Pylint, Clippy)

2. **Documentation Quality**
   - Complete README with quick start
   - API documentation (OpenAPI/Swagger)
   - SDK guides for all languages
   - Architecture diagrams
   - Troubleshooting guide

### Business Requirements ✅

1. **Commercial Viability**
   - Passes security review (OWASP Top 10)
   - Compliance-ready (PII redaction, audit logs)
   - Cost optimization ROI demonstrable
   - Production deployment guide

2. **Developer Experience**
   - Quick start < 5 minutes
   - Copy-paste examples work
   - Clear error messages
   - Comprehensive troubleshooting

---

## Commercial Deployment Guide

### Pre-Deployment Checklist

**Security:**
- [ ] All secrets in environment variables
- [ ] PII redaction enabled
- [ ] HTTPS/TLS configured
- [ ] API keys rotated
- [ ] Security scanning passed (Snyk, OWASP ZAP)

**Performance:**
- [ ] Load testing completed (1000 req/min)
- [ ] Database indexes optimized
- [ ] Caching configured
- [ ] CDN configured (if applicable)

**Monitoring:**
- [ ] All services instrumented
- [ ] Dashboards created in Grafana
- [ ] Alerts configured
- [ ] On-call rotation set up

**Compliance:**
- [ ] Audit logging enabled
- [ ] Data retention policies set
- [ ] Privacy policy updated
- [ ] Terms of service reviewed

### Deployment Steps

1. **Provision Infrastructure**
   ```bash
   # AWS
   terraform apply -var-file=production.tfvars

   # GCP
   gcloud deployment-manager deployments create example-app

   # Azure
   az deployment group create --template-file template.json
   ```

2. **Configure Secrets**
   ```bash
   # AWS Secrets Manager
   aws secretsmanager create-secret \
     --name example-app/openai-key \
     --secret-string $OPENAI_API_KEY

   # Kubernetes
   kubectl create secret generic app-secrets \
     --from-literal=openai-key=$OPENAI_API_KEY
   ```

3. **Deploy Services**
   ```bash
   # Docker Compose
   docker-compose -f docker-compose.prod.yml up -d

   # Kubernetes
   kubectl apply -f k8s/

   # Verify
   curl https://your-domain.com/health
   ```

4. **Run Migrations**
   ```bash
   docker-compose exec api python manage.py migrate
   ```

5. **Seed Data (Optional)**
   ```bash
   docker-compose exec api python manage.py seed_kb
   ```

6. **Verify Deployment**
   ```bash
   # Health checks
   curl https://your-domain.com/health

   # Send test message
   curl -X POST https://your-domain.com/api/v1/conversations/test/messages \
     -H "Content-Type: application/json" \
     -d '{"content": "test message"}'

   # Check traces in Observatory
   open https://grafana.your-domain.com
   ```

### Scaling Guide

**Horizontal Scaling:**
```yaml
# docker-compose.scale.yml
services:
  api:
    deploy:
      replicas: 3

  kb-api:
    deploy:
      replicas: 2
```

**Vertical Scaling:**
```yaml
# Increase resources
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

### Cost Optimization

**Expected Costs (1000 req/day):**
- LLM API calls: $200-400/month
- Infrastructure: $100-200/month
- Observatory storage: $50/month
- Total: $350-650/month

**Optimization Tips:**
1. Use GPT-3.5 for simple queries (70% cost reduction)
2. Cache common responses (30% reduction)
3. Optimize prompts (20% token reduction)
4. Use continuous aggregates (50% query cost reduction)

**Expected Savings with Observatory:**
- Identify unnecessary calls: -30%
- Optimize prompts: -20%
- Cache responses: -15%
- Switch models strategically: -25%
- **Total: 90% of original cost = 10% reduction pays for Observatory**

---

## Conclusion

This implementation plan provides a **comprehensive, enterprise-ready** example application that:

1. **Demonstrates Real Value**: Cost savings, performance optimization, quality improvement
2. **Accelerates Adoption**: Developers can start in minutes, not weeks
3. **Enables Scaling**: From prototype to production
4. **Builds Credibility**: Enterprise-grade code, security, compliance
5. **Drives Integration**: Reference for partners and customers

**Timeline:** 3 weeks
**Effort:** ~120 hours (1.5 FTE)
**ROI:** Dramatically accelerates LLM Observatory adoption and demonstrates clear business value

**Status:** Ready to implement 🚀
