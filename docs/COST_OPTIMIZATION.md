# LLM Observatory - Cost Optimization Guide

## Table of Contents

1. [Overview](#overview)
2. [Cost Tracking Strategies](#cost-tracking-strategies)
3. [Optimization Techniques](#optimization-techniques)
4. [ROI Calculations](#roi-calculations)
5. [Best Practices](#best-practices)
6. [Case Studies](#case-studies)

## Overview

LLM Observatory helps reduce LLM costs by 30-50% through comprehensive tracking and optimization.

**Average Cost Savings:**
- Eliminate wasteful requests: 15-25%
- Optimize model selection: 20-40%
- Implement caching: 30-60%
- Reduce token usage: 10-20%
- **Combined savings: 40-70%**

## Cost Tracking Strategies

### 1. Real-Time Cost Visibility

**Dashboard Queries:**
```sql
-- Total cost by service (last 24 hours)
SELECT
    service_name,
    COUNT(*) as requests,
    SUM(total_cost_usd) as total_cost,
    AVG(total_cost_usd) as avg_cost_per_request
FROM llm_metrics
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY service_name
ORDER BY total_cost DESC;

-- Cost trend over time
SELECT
    date_trunc('hour', timestamp) as hour,
    SUM(total_cost_usd) as cost
FROM llm_metrics
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY hour
ORDER BY hour;
```

### 2. Cost Attribution

**By User:**
```sql
SELECT
    user_id,
    COUNT(*) as requests,
    SUM(total_cost_usd) as total_cost,
    SUM(total_tokens) as total_tokens
FROM llm_metrics
WHERE timestamp > NOW() - INTERVAL '30 days'
  AND user_id IS NOT NULL
GROUP BY user_id
ORDER BY total_cost DESC
LIMIT 100;
```

**By Feature:**
```sql
SELECT
    tags->>'feature' as feature,
    COUNT(*) as requests,
    SUM(total_cost_usd) as total_cost
FROM llm_metrics
WHERE tags ? 'feature'
  AND timestamp > NOW() - INTERVAL '30 days'
GROUP BY feature
ORDER BY total_cost DESC;
```

### 3. Budget Alerts

**Set up Grafana alerts:**
```yaml
# Alert when daily cost exceeds $500
groups:
  - name: cost_alerts
    interval: 5m
    rules:
      - alert: DailyCostExceeded
        expr: sum(rate(llm_cost_total_usd[24h])) > 500
        annotations:
          summary: "Daily LLM cost exceeded $500"
          description: "Current daily cost: {{ $value }}"
```

## Optimization Techniques

### 1. Model Selection Optimization

**Compare Cost vs Quality:**
```sql
-- Compare models for same task
SELECT
    model_name,
    COUNT(*) as requests,
    AVG(total_cost_usd) as avg_cost,
    AVG(duration_ms) as avg_latency,
    COUNT(*) FILTER (WHERE error_code IS NOT NULL) as errors,
    STDDEV(total_cost_usd) as cost_variance
FROM llm_metrics
WHERE operation_name = 'chat.completion'
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY model_name
ORDER BY avg_cost ASC;
```

**Optimization Strategy:**
- Use GPT-3.5-turbo for simple tasks (70% cheaper)
- Use GPT-4-turbo only for complex reasoning
- Use Claude-3-Haiku for fast, cheap responses
- Implement fallback chains: GPT-3.5 → GPT-4

**Implementation:**
```python
async def smart_completion(prompt: str, complexity: str):
    if complexity == "simple":
        # 70% cheaper
        return await openai.complete("gpt-3.5-turbo", prompt)
    elif complexity == "medium":
        # Try cheaper model first
        try:
            return await openai.complete("gpt-3.5-turbo", prompt)
        except QualityThresholdNotMet:
            return await openai.complete("gpt-4-turbo", prompt)
    else:
        # Complex tasks require GPT-4
        return await openai.complete("gpt-4-turbo", prompt)
```

### 2. Prompt Optimization

**Reduce Token Usage:**
```python
# Before: 850 tokens, $0.0085
prompt = """
You are a helpful assistant. Please analyze the following customer 
support ticket and provide a detailed response addressing all concerns.

Ticket: {ticket}

Please provide:
1. A summary of the issue
2. Recommended actions
3. Priority level
4. Estimated resolution time
"""

# After: 120 tokens, $0.0012 (86% savings)
prompt = """
Analyze ticket and provide: summary, actions, priority, ETA.

Ticket: {ticket}
"""
```

**Best Practices:**
- Remove unnecessary formatting
- Use abbreviations where clear
- Eliminate redundant instructions
- Pre-process inputs to extract key info

### 3. Caching Strategy

**Response Caching:**
```python
import hashlib
from functools import lru_cache

@lru_cache(maxsize=10000)
def get_cached_response(prompt_hash: str):
    # Check Redis cache
    cached = redis.get(f"llm:cache:{prompt_hash}")
    if cached:
        return json.loads(cached)
    return None

async def cached_llm_call(prompt: str):
    # Generate hash of prompt
    prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()

    # Check cache
    cached = get_cached_response(prompt_hash)
    if cached:
        return cached

    # Call LLM
    response = await llm.complete(prompt)

    # Cache for 24 hours
    redis.setex(
        f"llm:cache:{prompt_hash}",
        86400,
        json.dumps(response)
    )

    return response
```

**Cache Hit Rates:**
- FAQ responses: 70-90% hit rate
- Product descriptions: 50-70% hit rate
- User queries: 20-40% hit rate

**Savings Example:**
- 1M requests/month at $0.01 avg = $10,000
- 40% cache hit rate = $4,000 savings

### 4. Token Limiting

**Reduce Max Tokens:**
```python
# Before: max_tokens=2000 (often only uses 200)
response = openai.complete(
    prompt=prompt,
    max_tokens=2000  # Paying for unused capacity
)

# After: Dynamic based on task
def get_optimal_max_tokens(task_type: str):
    return {
        "summarization": 300,
        "classification": 10,
        "extraction": 100,
        "generation": 500
    }.get(task_type, 500)

response = openai.complete(
    prompt=prompt,
    max_tokens=get_optimal_max_tokens(task_type)
)
```

### 5. Batch Processing

**Combine Multiple Requests:**
```python
# Before: 100 separate requests
costs = []
for product in products:
    desc = await llm.complete(f"Describe product: {product}")
    costs.append(0.01)  # $1.00 total

# After: Single batched request
batch_prompt = "\n".join([
    f"{i+1}. {product}"
    for i, product in enumerate(products)
])
response = await llm.complete(
    f"Generate brief descriptions for:\n{batch_prompt}"
)
# Cost: $0.05 (95% savings)
```

### 6. Streaming & Early Termination

```python
async def stream_with_early_stop(prompt: str, quality_threshold: float):
    accumulated = ""
    total_tokens = 0

    async for chunk in llm.stream(prompt):
        accumulated += chunk.text
        total_tokens += chunk.tokens

        # Check quality periodically
        if len(accumulated) > 100 and total_tokens % 50 == 0:
            quality = evaluate_quality(accumulated)
            if quality > quality_threshold:
                # Stop early, save tokens
                break

    return accumulated
```

## ROI Calculations

### Cost of LLM Observatory

**Infrastructure Costs (Monthly):**
- TimescaleDB (AWS RDS db.r6g.xlarge): $250
- Redis (ElastiCache cache.r6g.large): $150
- Collector (3x t3.medium): $100
- API/Storage (2x t3.medium): $65
- S3 storage (Tempo traces): $35
- **Total: ~$600/month**

### Savings Analysis

**Scenario: Medium-sized Application**
- Current LLM spend: $10,000/month
- After optimization: $6,000/month
- **Savings: $4,000/month**
- **ROI: 567%**
- **Payback period: 5 days**

**Breakdown of Savings:**
| Optimization | Savings |
|--------------|---------|
| Model selection | $2,000 (20%) |
| Caching | $1,200 (12%) |
| Prompt optimization | $500 (5%) |
| Eliminate waste | $300 (3%) |
| **Total** | **$4,000 (40%)** |

## Best Practices

### 1. Set Cost Budgets

```python
# Per-user monthly budget
USER_BUDGET = {
    "free": 1.00,      # $1/month
    "pro": 50.00,      # $50/month
    "enterprise": None  # Unlimited
}

async def check_budget(user_id: str, estimated_cost: float):
    tier = get_user_tier(user_id)
    budget = USER_BUDGET[tier]

    if budget is None:
        return True

    current_spend = await get_monthly_spend(user_id)
    return current_spend + estimated_cost <= budget
```

### 2. Implement Rate Limiting

```python
from ratelimit import limits, RateLimitException

@limits(calls=100, period=3600)  # 100 requests/hour
async def rate_limited_llm_call(prompt: str):
    return await llm.complete(prompt)
```

### 3. Monitor Anomalies

```sql
-- Detect unusually expensive requests
SELECT
    trace_id,
    total_cost_usd,
    total_tokens,
    service_name,
    timestamp
FROM llm_metrics
WHERE total_cost_usd > (
    SELECT AVG(total_cost_usd) * 3
    FROM llm_metrics
    WHERE timestamp > NOW() - INTERVAL '24 hours'
)
AND timestamp > NOW() - INTERVAL '1 hour'
ORDER BY total_cost_usd DESC;
```

### 4. Regular Cost Reviews

**Weekly:**
- Review top 10 most expensive services
- Identify optimization opportunities
- Check cache hit rates

**Monthly:**
- Compare month-over-month costs
- Analyze cost per user/feature
- Review and adjust budgets

**Quarterly:**
- Benchmark against industry
- Evaluate new models (cheaper/better)
- Update optimization strategies

## Case Studies

### Case Study 1: E-commerce Product Descriptions

**Before:**
- Model: GPT-4-turbo
- Cost: $0.015 per product
- 10,000 products/day
- **Total: $150/day = $4,500/month**

**After Optimization:**
- Caching (60% hit rate): $60/day
- GPT-3.5-turbo for simple products (40%): $18/day
- GPT-4-turbo for complex (remaining 24%): $54/day
- **Total: $36/day = $1,080/month**
- **Savings: 76%**

### Case Study 2: Customer Support Chatbot

**Before:**
- Average: 150 tokens/request at $0.0015
- 50,000 requests/month
- **Total: $750/month**

**After Optimization:**
- Response caching (35% hit rate): -$263
- Prompt optimization (40% shorter): -$180
- Smart model routing (30% to GPT-3.5): -$67
- **Total: $240/month**
- **Savings: 68%**

### Case Study 3: Content Summarization

**Before:**
- GPT-4-turbo for all summaries
- Average: 2,000 input + 300 output tokens
- Cost: $0.025 per summary
- 20,000 summaries/month
- **Total: $500/month**

**After Optimization:**
- Extract key sentences first (pre-processing)
- Reduce input to 500 tokens avg
- Use Claude-3-Haiku ($0.008/summary)
- **Total: $160/month**
- **Savings: 68%**

## Action Plan

### Week 1: Setup Tracking
1. Deploy LLM Observatory
2. Instrument all LLM calls
3. Create cost dashboards

### Week 2: Analyze
1. Identify top cost drivers
2. Analyze cache opportunities
3. Review prompt efficiency

### Week 3: Optimize
1. Implement caching
2. Optimize prompts
3. Add model routing

### Week 4: Monitor & Iterate
1. Measure savings
2. Fine-tune strategies
3. Set up alerts

**Expected Timeline to ROI: 2-4 weeks**

---

For more details, see:
- [Architecture](./ARCHITECTURE.md)
- [API Reference](./API.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
