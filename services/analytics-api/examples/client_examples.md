# LLM Observatory REST API - Client Examples

This document provides complete client implementation examples for integrating with the LLM Observatory REST API in multiple programming languages.

## Table of Contents

1. [Python Client](#python-client)
2. [JavaScript/TypeScript Client](#javascripttypescript-client)
3. [cURL Examples](#curl-examples)
4. [Postman Collection](#postman-collection)

---

## Python Client

### Installation

```bash
pip install requests pyjwt
```

### Complete Python Client Implementation

```python
import requests
import jwt
import time
from datetime import datetime, timedelta
from typing import Optional, Dict, List, Any
from dataclasses import dataclass

@dataclass
class TraceQuery:
    """Query parameters for listing traces."""
    from_time: Optional[str] = None
    to_time: Optional[str] = None
    provider: Optional[str] = None
    model: Optional[str] = None
    status: Optional[str] = None
    min_duration: Optional[int] = None
    max_duration: Optional[int] = None
    min_cost: Optional[float] = None
    max_cost: Optional[float] = None
    environment: Optional[str] = None
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    search: Optional[str] = None
    cursor: Optional[str] = None
    limit: int = 50
    sort_by: Optional[str] = "ts"
    sort_order: Optional[str] = "desc"

class ObservatoryAPIClient:
    """Client for LLM Observatory REST API."""

    def __init__(
        self,
        base_url: str = "http://localhost:8080",
        jwt_token: Optional[str] = None,
        jwt_secret: Optional[str] = None,
        user_id: Optional[str] = None,
        org_id: Optional[str] = None,
        projects: Optional[List[str]] = None,
        role: str = "developer"
    ):
        """
        Initialize the API client.

        Args:
            base_url: Base URL of the API
            jwt_token: Pre-generated JWT token (if available)
            jwt_secret: JWT secret for generating tokens
            user_id: User ID for token generation
            org_id: Organization ID for token generation
            projects: List of accessible project IDs
            role: User role (admin, developer, viewer, billing)
        """
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()

        if jwt_token:
            self.token = jwt_token
        elif jwt_secret and user_id and org_id:
            self.token = self._generate_token(
                jwt_secret, user_id, org_id, projects or [], role
            )
        else:
            raise ValueError("Either jwt_token or (jwt_secret, user_id, org_id) must be provided")

        self.session.headers.update({
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        })

    def _generate_token(
        self,
        secret: str,
        user_id: str,
        org_id: str,
        projects: List[str],
        role: str
    ) -> str:
        """Generate a JWT token."""
        permissions = {
            'admin': ['*'],
            'developer': ['read:traces', 'read:metrics', 'read:costs', 'write:evaluations'],
            'viewer': ['read:traces', 'read:metrics', 'read:costs'],
            'billing': ['read:costs', 'read:usage']
        }

        now = int(time.time())
        payload = {
            'sub': user_id,
            'org_id': org_id,
            'projects': projects,
            'role': role,
            'permissions': permissions.get(role, []),
            'iat': now,
            'exp': now + 3600,  # 1 hour
            'jti': f'{user_id}-{now}'
        }

        return jwt.encode(payload, secret, algorithm='HS256')

    def _handle_response(self, response: requests.Response) -> Dict[str, Any]:
        """Handle API response and extract data."""
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 401:
            raise Exception(f"Authentication failed: {response.json()}")
        elif response.status_code == 403:
            raise Exception(f"Authorization failed: {response.json()}")
        elif response.status_code == 429:
            headers = response.headers
            retry_after = headers.get('Retry-After', '60')
            raise Exception(
                f"Rate limit exceeded. Retry after {retry_after} seconds. "
                f"Limit: {headers.get('X-RateLimit-Limit')}, "
                f"Remaining: {headers.get('X-RateLimit-Remaining')}"
            )
        else:
            raise Exception(f"API error: {response.status_code} - {response.text}")

    def list_traces(self, query: Optional[TraceQuery] = None) -> Dict[str, Any]:
        """
        List traces with optional filtering.

        Args:
            query: TraceQuery object with filter parameters

        Returns:
            Dictionary with 'data', 'pagination', and 'meta' keys
        """
        params = {}

        if query:
            if query.from_time:
                params['from'] = query.from_time
            if query.to_time:
                params['to'] = query.to_time
            if query.provider:
                params['provider'] = query.provider
            if query.model:
                params['model'] = query.model
            if query.status:
                params['status'] = query.status
            if query.min_duration:
                params['min_duration'] = query.min_duration
            if query.max_duration:
                params['max_duration'] = query.max_duration
            if query.min_cost:
                params['min_cost'] = query.min_cost
            if query.max_cost:
                params['max_cost'] = query.max_cost
            if query.environment:
                params['environment'] = query.environment
            if query.user_id:
                params['user_id'] = query.user_id
            if query.session_id:
                params['session_id'] = query.session_id
            if query.search:
                params['search'] = query.search
            if query.cursor:
                params['cursor'] = query.cursor
            if query.limit:
                params['limit'] = query.limit
            if query.sort_by:
                params['sort_by'] = query.sort_by
            if query.sort_order:
                params['sort_order'] = query.sort_order

        response = self.session.get(f'{self.base_url}/api/v1/traces', params=params)
        return self._handle_response(response)

    def get_trace(self, trace_id: str) -> Dict[str, Any]:
        """
        Get a single trace by ID.

        Args:
            trace_id: The trace ID to retrieve

        Returns:
            Dictionary with trace data
        """
        response = self.session.get(f'{self.base_url}/api/v1/traces/{trace_id}')
        return self._handle_response(response)

    def iterate_all_traces(
        self,
        query: Optional[TraceQuery] = None,
        max_results: Optional[int] = None
    ):
        """
        Generator that iterates through all traces using cursor-based pagination.

        Args:
            query: TraceQuery object with filter parameters
            max_results: Maximum number of results to return

        Yields:
            Individual trace dictionaries
        """
        query = query or TraceQuery()
        count = 0

        while True:
            result = self.list_traces(query)

            for trace in result['data']:
                yield trace
                count += 1

                if max_results and count >= max_results:
                    return

            # Check if there are more results
            if not result['pagination']['has_more']:
                break

            # Update cursor for next page
            query.cursor = result['pagination']['cursor']

    def search_traces(
        self,
        search_text: str,
        limit: int = 50,
        provider: Optional[str] = None,
        model: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Search traces by text content.

        Args:
            search_text: Text to search for in input/output
            limit: Number of results to return
            provider: Optional provider filter
            model: Optional model filter

        Returns:
            Dictionary with matching traces
        """
        query = TraceQuery(
            search=search_text,
            limit=limit,
            provider=provider,
            model=model
        )
        return self.list_traces(query)

    def get_expensive_traces(
        self,
        min_cost: float = 0.01,
        limit: int = 100,
        days: int = 7
    ) -> Dict[str, Any]:
        """
        Get the most expensive traces.

        Args:
            min_cost: Minimum cost threshold in USD
            limit: Number of results to return
            days: Number of days to look back

        Returns:
            Dictionary with expensive traces
        """
        from_time = (datetime.utcnow() - timedelta(days=days)).isoformat() + 'Z'

        query = TraceQuery(
            from_time=from_time,
            min_cost=min_cost,
            limit=limit,
            sort_by='total_cost_usd',
            sort_order='desc'
        )
        return self.list_traces(query)

    def get_slow_traces(
        self,
        min_duration: int = 5000,
        limit: int = 100,
        days: int = 7
    ) -> Dict[str, Any]:
        """
        Get the slowest traces.

        Args:
            min_duration: Minimum duration in milliseconds
            limit: Number of results to return
            days: Number of days to look back

        Returns:
            Dictionary with slow traces
        """
        from_time = (datetime.utcnow() - timedelta(days=days)).isoformat() + 'Z'

        query = TraceQuery(
            from_time=from_time,
            min_duration=min_duration,
            limit=limit,
            sort_by='duration_ms',
            sort_order='desc'
        )
        return self.list_traces(query)

    def get_error_traces(
        self,
        limit: int = 100,
        days: int = 1
    ) -> Dict[str, Any]:
        """
        Get traces with errors.

        Args:
            limit: Number of results to return
            days: Number of days to look back

        Returns:
            Dictionary with error traces
        """
        from_time = (datetime.utcnow() - timedelta(days=days)).isoformat() + 'Z'

        query = TraceQuery(
            from_time=from_time,
            status='ERROR',
            limit=limit,
            sort_by='ts',
            sort_order='desc'
        )
        return self.list_traces(query)

# Example usage
if __name__ == '__main__':
    # Initialize client
    client = ObservatoryAPIClient(
        base_url='http://localhost:8080',
        jwt_secret='your_jwt_secret_min_32_chars',
        user_id='user_123',
        org_id='org_456',
        projects=['proj_001'],
        role='developer'
    )

    # Example 1: List recent traces
    print("=== Recent Traces ===")
    result = client.list_traces(TraceQuery(limit=5))
    print(f"Found {len(result['data'])} traces")
    for trace in result['data']:
        print(f"  {trace['trace_id']}: {trace['provider']}/{trace['model']} - ${trace.get('total_cost_usd', 0):.4f}")

    # Example 2: Search for errors
    print("\n=== Error Traces ===")
    errors = client.get_error_traces(limit=10)
    print(f"Found {len(errors['data'])} errors")
    for trace in errors['data']:
        print(f"  {trace['trace_id']}: {trace.get('error_message', 'Unknown error')}")

    # Example 3: Find expensive traces
    print("\n=== Expensive Traces ===")
    expensive = client.get_expensive_traces(min_cost=0.01, limit=10)
    print(f"Found {len(expensive['data'])} expensive traces")
    for trace in expensive['data']:
        print(f"  {trace['trace_id']}: ${trace.get('total_cost_usd', 0):.4f}")

    # Example 4: Iterate through all traces (with limit)
    print("\n=== Iterate All Traces ===")
    for i, trace in enumerate(client.iterate_all_traces(max_results=20)):
        print(f"  {i+1}. {trace['trace_id']}")

    # Example 5: Search traces
    print("\n=== Search Results ===")
    search_results = client.search_traces("timeout error", limit=10)
    print(f"Found {len(search_results['data'])} matching traces")

    # Example 6: Get specific trace
    if result['data']:
        trace_id = result['data'][0]['trace_id']
        print(f"\n=== Single Trace: {trace_id} ===")
        single_trace = client.get_trace(trace_id)
        print(f"Provider: {single_trace['data']['provider']}")
        print(f"Model: {single_trace['data']['model']}")
        print(f"Duration: {single_trace['data'].get('duration_ms')}ms")
        print(f"Cost: ${single_trace['data'].get('total_cost_usd', 0):.4f}")
```

---

## JavaScript/TypeScript Client

### Installation

```bash
npm install axios jsonwebtoken
```

### Complete TypeScript Client Implementation

```typescript
import axios, { AxiosInstance, AxiosResponse } from 'axios';
import jwt from 'jsonwebtoken';

interface TraceQuery {
  from?: string;
  to?: string;
  provider?: string;
  model?: string;
  status?: string;
  min_duration?: number;
  max_duration?: number;
  min_cost?: number;
  max_cost?: number;
  environment?: string;
  user_id?: string;
  session_id?: string;
  search?: string;
  cursor?: string;
  limit?: number;
  sort_by?: string;
  sort_order?: 'asc' | 'desc';
}

interface Trace {
  ts: string;
  trace_id: string;
  span_id: string;
  parent_span_id?: string;
  provider: string;
  model: string;
  input_text?: string;
  output_text?: string;
  prompt_tokens?: number;
  completion_tokens?: number;
  total_tokens?: number;
  prompt_cost_usd?: number;
  completion_cost_usd?: number;
  total_cost_usd?: number;
  duration_ms?: number;
  ttft_ms?: number;
  status_code?: string;
  error_message?: string;
  user_id?: string;
  session_id?: string;
  environment?: string;
  tags?: string[];
  attributes?: any;
}

interface PaginationMetadata {
  cursor?: string;
  has_more: boolean;
  limit: number;
  total?: number;
}

interface ResponseMetadata {
  timestamp: string;
  execution_time_ms: number;
  cached: boolean;
  version: string;
  request_id?: string;
}

interface TracesResponse {
  status: 'success' | 'error';
  data: Trace[];
  pagination: PaginationMetadata;
  meta: ResponseMetadata;
}

interface SingleTraceResponse {
  status: 'success' | 'error';
  data: Trace;
  meta: ResponseMetadata;
}

interface JwtPayload {
  sub: string;
  org_id: string;
  projects: string[];
  role: string;
  permissions: string[];
  iat: number;
  exp: number;
  jti: string;
}

class ObservatoryAPIClient {
  private client: AxiosInstance;
  private token: string;

  constructor(config: {
    baseURL?: string;
    jwtToken?: string;
    jwtSecret?: string;
    userId?: string;
    orgId?: string;
    projects?: string[];
    role?: 'admin' | 'developer' | 'viewer' | 'billing';
  }) {
    const {
      baseURL = 'http://localhost:8080',
      jwtToken,
      jwtSecret,
      userId,
      orgId,
      projects = [],
      role = 'developer'
    } = config;

    if (jwtToken) {
      this.token = jwtToken;
    } else if (jwtSecret && userId && orgId) {
      this.token = this.generateToken(jwtSecret, userId, orgId, projects, role);
    } else {
      throw new Error('Either jwtToken or (jwtSecret, userId, orgId) must be provided');
    }

    this.client = axios.create({
      baseURL,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json'
      },
      timeout: 30000
    });

    // Add response interceptor for error handling
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        if (error.response) {
          const { status, data, headers } = error.response;

          if (status === 429) {
            const retryAfter = headers['retry-after'];
            const limit = headers['x-ratelimit-limit'];
            const remaining = headers['x-ratelimit-remaining'];
            throw new Error(
              `Rate limit exceeded. Retry after ${retryAfter}s. ` +
              `Limit: ${limit}, Remaining: ${remaining}`
            );
          }

          throw new Error(`API Error ${status}: ${JSON.stringify(data)}`);
        }
        throw error;
      }
    );
  }

  private generateToken(
    secret: string,
    userId: string,
    orgId: string,
    projects: string[],
    role: string
  ): string {
    const permissions: Record<string, string[]> = {
      admin: ['*'],
      developer: ['read:traces', 'read:metrics', 'read:costs', 'write:evaluations'],
      viewer: ['read:traces', 'read:metrics', 'read:costs'],
      billing: ['read:costs', 'read:usage']
    };

    const now = Math.floor(Date.now() / 1000);
    const payload: JwtPayload = {
      sub: userId,
      org_id: orgId,
      projects,
      role,
      permissions: permissions[role] || [],
      iat: now,
      exp: now + 3600, // 1 hour
      jti: `${userId}-${now}`
    };

    return jwt.sign(payload, secret);
  }

  async listTraces(query?: TraceQuery): Promise<TracesResponse> {
    const response = await this.client.get<TracesResponse>('/api/v1/traces', {
      params: query
    });
    return response.data;
  }

  async getTrace(traceId: string): Promise<SingleTraceResponse> {
    const response = await this.client.get<SingleTraceResponse>(
      `/api/v1/traces/${traceId}`
    );
    return response.data;
  }

  async *iterateAllTraces(query?: TraceQuery, maxResults?: number): AsyncGenerator<Trace> {
    let currentQuery = { ...query, limit: query?.limit || 50 };
    let count = 0;

    while (true) {
      const result = await this.listTraces(currentQuery);

      for (const trace of result.data) {
        yield trace;
        count++;

        if (maxResults && count >= maxResults) {
          return;
        }
      }

      if (!result.pagination.has_more) {
        break;
      }

      currentQuery.cursor = result.pagination.cursor;
    }
  }

  async searchTraces(
    searchText: string,
    options?: {
      limit?: number;
      provider?: string;
      model?: string;
    }
  ): Promise<TracesResponse> {
    return this.listTraces({
      search: searchText,
      limit: options?.limit || 50,
      provider: options?.provider,
      model: options?.model
    });
  }

  async getExpensiveTraces(
    options?: {
      minCost?: number;
      limit?: number;
      days?: number;
    }
  ): Promise<TracesResponse> {
    const { minCost = 0.01, limit = 100, days = 7 } = options || {};

    const from = new Date();
    from.setDate(from.getDate() - days);

    return this.listTraces({
      from: from.toISOString(),
      min_cost: minCost,
      limit,
      sort_by: 'total_cost_usd',
      sort_order: 'desc'
    });
  }

  async getSlowTraces(
    options?: {
      minDuration?: number;
      limit?: number;
      days?: number;
    }
  ): Promise<TracesResponse> {
    const { minDuration = 5000, limit = 100, days = 7 } = options || {};

    const from = new Date();
    from.setDate(from.getDate() - days);

    return this.listTraces({
      from: from.toISOString(),
      min_duration: minDuration,
      limit,
      sort_by: 'duration_ms',
      sort_order: 'desc'
    });
  }

  async getErrorTraces(
    options?: {
      limit?: number;
      days?: number;
    }
  ): Promise<TracesResponse> {
    const { limit = 100, days = 1 } = options || {};

    const from = new Date();
    from.setDate(from.getDate() - days);

    return this.listTraces({
      from: from.toISOString(),
      status: 'ERROR',
      limit,
      sort_by: 'ts',
      sort_order: 'desc'
    });
  }
}

// Example usage
async function main() {
  const client = new ObservatoryAPIClient({
    baseURL: 'http://localhost:8080',
    jwtSecret: 'your_jwt_secret_min_32_chars',
    userId: 'user_123',
    orgId: 'org_456',
    projects: ['proj_001'],
    role: 'developer'
  });

  // Example 1: List recent traces
  console.log('=== Recent Traces ===');
  const traces = await client.listTraces({ limit: 5 });
  console.log(`Found ${traces.data.length} traces`);
  traces.data.forEach(trace => {
    console.log(
      `  ${trace.trace_id}: ${trace.provider}/${trace.model} - ` +
      `$${trace.total_cost_usd?.toFixed(4) || '0.0000'}`
    );
  });

  // Example 2: Search traces
  console.log('\n=== Search Results ===');
  const searchResults = await client.searchTraces('timeout error', { limit: 10 });
  console.log(`Found ${searchResults.data.length} matching traces`);

  // Example 3: Get expensive traces
  console.log('\n=== Expensive Traces ===');
  const expensive = await client.getExpensiveTraces({ minCost: 0.01, limit: 10 });
  console.log(`Found ${expensive.data.length} expensive traces`);
  expensive.data.forEach(trace => {
    console.log(`  ${trace.trace_id}: $${trace.total_cost_usd?.toFixed(4) || '0.0000'}`);
  });

  // Example 4: Iterate all traces
  console.log('\n=== Iterate All Traces ===');
  let count = 0;
  for await (const trace of client.iterateAllTraces({}, 20)) {
    count++;
    console.log(`  ${count}. ${trace.trace_id}`);
  }

  // Example 5: Get specific trace
  if (traces.data.length > 0) {
    const traceId = traces.data[0].trace_id;
    console.log(`\n=== Single Trace: ${traceId} ===`);
    const singleTrace = await client.getTrace(traceId);
    console.log(`Provider: ${singleTrace.data.provider}`);
    console.log(`Model: ${singleTrace.data.model}`);
    console.log(`Duration: ${singleTrace.data.duration_ms}ms`);
    console.log(`Cost: $${singleTrace.data.total_cost_usd?.toFixed(4) || '0.0000'}`);
  }
}

main().catch(console.error);

export { ObservatoryAPIClient, TraceQuery, Trace, TracesResponse };
```

---

## cURL Examples

### Basic Authentication

```bash
# Generate JWT token (using jwt.io or a tool)
JWT_TOKEN="your_generated_jwt_token"

# Set base URL
API_URL="http://localhost:8080"
```

### List All Traces

```bash
curl -X GET "${API_URL}/api/v1/traces?limit=10" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -H "Content-Type: application/json"
```

### Filter by Provider and Model

```bash
curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "provider=openai" \
  --data-urlencode "model=gpt-4" \
  --data-urlencode "limit=50"
```

### Filter by Time Range

```bash
curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "from=2025-11-01T00:00:00Z" \
  --data-urlencode "to=2025-11-05T23:59:59Z" \
  --data-urlencode "limit=100"
```

### Filter by Cost Range

```bash
curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "min_cost=0.01" \
  --data-urlencode "max_cost=1.0" \
  --data-urlencode "sort_by=total_cost_usd" \
  --data-urlencode "sort_order=desc" \
  --data-urlencode "limit=50"
```

### Full-Text Search

```bash
curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "search=timeout error" \
  --data-urlencode "limit=20"
```

### Get Single Trace

```bash
TRACE_ID="trace_abc123"

curl -X GET "${API_URL}/api/v1/traces/${TRACE_ID}" \
  -H "Authorization: Bearer ${JWT_TOKEN}"
```

### Paginated Request

```bash
# First page
curl -X GET "${API_URL}/api/v1/traces?limit=50" \
  -H "Authorization: Bearer ${JWT_TOKEN}"

# Extract cursor from response, then:
CURSOR="eyJ0aW1lc3RhbXAiOi4uLn0="

curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "cursor=${CURSOR}" \
  --data-urlencode "limit=50"
```

### Complex Filter Example

```bash
curl -X GET "${API_URL}/api/v1/traces" \
  -H "Authorization: Bearer ${JWT_TOKEN}" \
  -G \
  --data-urlencode "from=2025-11-01T00:00:00Z" \
  --data-urlencode "to=2025-11-05T23:59:59Z" \
  --data-urlencode "provider=openai" \
  --data-urlencode "model=gpt-4" \
  --data-urlencode "min_cost=0.01" \
  --data-urlencode "max_duration=5000" \
  --data-urlencode "environment=production" \
  --data-urlencode "status=OK" \
  --data-urlencode "limit=50" \
  --data-urlencode "sort_by=total_cost_usd" \
  --data-urlencode "sort_order=desc"
```

### Check Rate Limits

```bash
curl -i -X GET "${API_URL}/api/v1/traces?limit=1" \
  -H "Authorization: Bearer ${JWT_TOKEN}"

# Check headers:
# X-RateLimit-Limit: 10000
# X-RateLimit-Remaining: 9995
# X-RateLimit-Reset: 1699203660
```

---

## Postman Collection

Create a new Postman collection with the following setup:

### Collection Variables

```
base_url: http://localhost:8080
jwt_token: your_jwt_token_here
```

### Authorization

- Type: Bearer Token
- Token: {{jwt_token}}

### Requests

#### 1. List Traces

- Method: GET
- URL: `{{base_url}}/api/v1/traces`
- Params:
  - limit: 10
  - provider: openai

#### 2. Get Single Trace

- Method: GET
- URL: `{{base_url}}/api/v1/traces/:trace_id`
- Path Variable: trace_id

#### 3. Search Traces

- Method: GET
- URL: `{{base_url}}/api/v1/traces`
- Params:
  - search: error timeout
  - limit: 20

#### 4. Filter by Cost

- Method: GET
- URL: `{{base_url}}/api/v1/traces`
- Params:
  - min_cost: 0.01
  - max_cost: 1.0
  - sort_by: total_cost_usd
  - sort_order: desc

---

## Error Handling

All clients should handle these common errors:

### 401 Unauthorized

```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Invalid or expired token"
  }
}
```

**Solution:** Regenerate JWT token

### 429 Too Many Requests

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Too many requests. Please slow down."
  }
}
```

**Headers:**
- `X-RateLimit-Limit`: Total limit
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Unix timestamp when limit resets
- `Retry-After`: Seconds to wait before retrying

**Solution:** Implement exponential backoff

### 404 Not Found

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Trace with ID 'xyz' not found"
  }
}
```

**Solution:** Verify trace ID exists

---

## Best Practices

1. **Token Management**
   - Generate tokens with appropriate expiration (1 hour recommended)
   - Refresh tokens before expiration
   - Store tokens securely (environment variables, secure storage)

2. **Rate Limiting**
   - Implement exponential backoff
   - Monitor X-RateLimit-* headers
   - Use batch operations when possible

3. **Pagination**
   - Always use cursor-based pagination for large datasets
   - Store cursor for resuming interrupted queries
   - Don't rely on offset-based pagination for production

4. **Error Handling**
   - Retry on 5xx errors with exponential backoff
   - Log all errors with request IDs for debugging
   - Handle rate limits gracefully

5. **Performance**
   - Use appropriate filters to reduce result set size
   - Leverage caching on API side (historical queries)
   - Use search judiciously (full-text search is expensive)

---

## Support

For issues or questions:
- GitHub Issues: https://github.com/llm-observatory/llm-observatory/issues
- Documentation: https://docs.llm-observatory.io
- Email: support@llm-observatory.io
