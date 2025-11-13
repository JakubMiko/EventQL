# Thesis Testing Plan: GraphQL vs REST/Grape Performance & Security Comparison

## Project Overview
Comparing two identical event ticketing applications:
- **App A:** GraphQL (graphql-ruby) - This repository
- **App B:** REST/Grape - Separate repository

## Testing Infrastructure

### Environment Setup: Docker Compose

**Why Docker:**
- ✅ Reproducible across machines
- ✅ Controlled resource limits
- ✅ Isolated testing environments
- ✅ Easy to document in thesis
- ✅ Can run on local machine or DigitalOcean server

**Architecture:**
```
┌─────────────────────────────────────────────────────┐
│                    Docker Network                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │ GraphQL App  │  │  REST App    │  │PostgreSQL│  │
│  │ Port: 3000   │  │ Port: 3001   │  │Port: 5432│  │
│  │ CPU: 2 cores │  │ CPU: 2 cores │  │          │  │
│  │ RAM: 2GB     │  │ RAM: 2GB     │  │          │  │
│  └──────────────┘  └──────────────┘  └──────────┘  │
│         ▲                 ▲                          │
│         │                 │                          │
│         └─────────┬───────┘                          │
│                   │                                  │
│            ┌──────┴──────┐                           │
│            │   k6 Runner │                           │
│            │ (Load Tests)│                           │
│            └─────────────┘                           │
│                   │                                  │
│                   ▼                                  │
│         ┌─────────────────┐                          │
│         │ InfluxDB        │                          │
│         │ (Metrics Store) │                          │
│         └────────┬────────┘                          │
│                  │                                   │
│                  ▼                                   │
│         ┌─────────────────┐                          │
│         │ Grafana         │                          │
│         │ (Visualization) │                          │
│         │ Port: 3002      │                          │
│         └─────────────────┘                          │
└─────────────────────────────────────────────────────┘
```

### Metrics Collection & Visualization

**Stack: k6 + InfluxDB + Grafana (100% Free, Self-Hosted)**

**What you get:**
- Real-time dashboards during tests
- Historical comparison charts
- Export charts as PNG for thesis
- Raw data for statistical analysis
- Professional-looking visualizations

**Alternative:** k6 HTML reports (simpler, still good for thesis)

---

## PART 1: PERFORMANCE TESTING

### Test Scenarios Matrix

| # | Scenario | Load | Stress | Spike | Soak | Rationale |
|---|----------|------|--------|-------|------|-----------|
| 1 | Simple Read | ✅ | ❌ | ❌ | ❌ | Baseline comparison |
| 2 | List + Filtering | ✅ | ✅ | ❌ | ❌ | Common operation |
| 3 | **Nested Data** | ✅ | ✅ | ✅ | ✅ | **KEY DIFFERENCE** - GraphQL advantage |
| 4 | **Selective Fields** | ✅ | ❌ | ❌ | ❌ | **KEY DIFFERENCE** - Over-fetching |
| 5 | Write Operations | ✅ | ✅ | ❌ | ❌ | Mutation performance |
| 6 | Complex Mutations | ✅ | ✅ | ✅ | ❌ | Transaction handling |
| 7 | Concurrent Users | ✅ | ✅ | ✅ | ✅ | Real-world simulation |

**Total Tests: 24 (instead of 56)**
- 14 Load Tests (all scenarios x 2 APIs)
- 6 Stress Tests (critical scenarios x 2 APIs)
- 4 Spike Tests (critical scenarios x 2 APIs)
- 2 Soak Tests (most important scenarios x 2 APIs)

### Test Types Definition

#### Load Test (Baseline Performance)
```javascript
// Gradual ramp-up to sustained load
export let options = {
  stages: [
    { duration: '1m', target: 10 },   // Warm up
    { duration: '3m', target: 50 },   // Normal load
    { duration: '1m', target: 0 },    // Cool down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% requests under 500ms
    http_req_failed: ['rate<0.01'],   // Error rate under 1%
  },
};
```
**Measures:** Baseline performance under normal conditions

#### Stress Test (Find Breaking Point)
```javascript
// Push system to limits
export let options = {
  stages: [
    { duration: '2m', target: 50 },   // Normal
    { duration: '3m', target: 100 },  // Stress
    { duration: '3m', target: 200 },  // High stress
    { duration: '2m', target: 0 },    // Recovery
  ],
};
```
**Measures:** Maximum capacity, degradation patterns, recovery

#### Spike Test (Sudden Traffic Bursts)
```javascript
// Simulate sudden traffic spike (e.g., ticket sale launch)
export let options = {
  stages: [
    { duration: '30s', target: 20 },  // Normal
    { duration: '1m', target: 200 },  // SPIKE!
    { duration: '30s', target: 20 },  // Back to normal
  ],
};
```
**Measures:** Response to sudden load, auto-scaling behavior

#### Soak Test (Memory Leaks, Stability)
```javascript
// Extended test for memory leaks
export let options = {
  stages: [
    { duration: '5m', target: 50 },   // Ramp up
    { duration: '2h', target: 50 },   // Sustained load
    { duration: '5m', target: 0 },    // Cool down
  ],
};
```
**Measures:** Memory leaks, resource exhaustion, long-term stability

### Metrics to Collect

#### Response Time Metrics
- **Mean response time** - Average performance
- **Median (p50)** - Typical user experience
- **p95** - 95th percentile (SLA metric)
- **p99** - 99th percentile (worst case)
- **Min/Max** - Performance range

#### Throughput Metrics
- **Requests/second** - Server capacity
- **Virtual Users (VUs)** - Concurrent load
- **Request rate** - Requests over time

#### Resource Metrics (via Docker stats)
- **CPU usage %** - Processing load
- **Memory usage MB** - RAM consumption
- **Memory usage %** - RAM percentage
- **Network I/O** - Bandwidth usage

#### Database Metrics (PostgreSQL logs)
- **Query count per request** - N+1 detection
- **Query execution time** - DB performance
- **Connection pool usage** - Resource management
- **Cache hit ratio** - Caching efficiency

#### Application Metrics
- **Error rate %** - Reliability
- **HTTP status codes** - Error types
- **Data transfer size** - Payload comparison

### Expected Key Findings

#### Where GraphQL Should Win:
1. **Nested Data Retrieval** - Single request vs multiple
2. **Selective Fields** - Smaller payloads
3. **Complex Data Requirements** - Fewer round trips
4. **Network Bandwidth** - Less data transfer

#### Where REST Might Win:
1. **Simple Operations** - Less overhead
2. **Caching** - HTTP caching easier
3. **Predictability** - Fixed response structure

#### Where They Should Be Similar:
1. **Write Operations** - Similar complexity
2. **Database Performance** - Same DB queries
3. **Authentication** - Same JWT mechanism

---

## PART 2: SECURITY TESTING

### Security Testing Approach

**Two-pronged approach:**
1. **Automated Scanning** - Find common vulnerabilities
2. **Manual Testing** - Test specific attack vectors

### Common Security Tests (Both APIs)

#### 1. Static Analysis

**Brakeman (Works for both!)**
```bash
# Both apps are Rails-based, Brakeman scans:
# - SQL injection risks
# - XSS vulnerabilities
# - Mass assignment issues
# - Authentication flaws
# - Sensitive data exposure

brakeman -A -q --no-pager
```

**Bundler Audit**
```bash
# Check for vulnerable gems
bundle audit check --update
```

**RuboCop Security**
```bash
# Security-focused linting
rubocop --only Security
```

#### 2. Authentication & Authorization Testing

**Test Cases:**
| Test | GraphQL Endpoint | REST Endpoint | Expected Result |
|------|------------------|---------------|-----------------|
| No token | `query { currentUser }` | `GET /api/v1/current_user` | 401 Unauthorized |
| Invalid token | `query { currentUser }` | `GET /api/v1/current_user` | 401 Unauthorized |
| Expired token | `query { currentUser }` | `GET /api/v1/current_user` | 401 Unauthorized |
| User access admin | `mutation { createEvent }` | `POST /api/v1/events` | 403 Forbidden |
| Access other's data | `query { order(id: "X") }` | `GET /api/v1/orders/X` | 403 Forbidden |

**Tool:** Manual testing with Postman/Insomnia + scripted tests

#### 3. Input Validation Testing

**SQL Injection Attempts:**
```javascript
// GraphQL
mutation {
  register(input: {
    email: "test@test.com'; DROP TABLE users; --"
    password: "password"
  })
}

// REST
POST /api/v1/users/register
{
  "email": "test@test.com'; DROP TABLE users; --",
  "password": "password"
}
```

**XSS Payloads:**
```javascript
// Test in text fields
name: "<script>alert('XSS')</script>"
description: "<img src=x onerror=alert('XSS')>"
```

**Tool:** OWASP ZAP (automated scanner)

#### 4. Rate Limiting Testing

**Test Cases:**
- Send 1000 requests in 1 minute (should be blocked)
- Verify 429 Too Many Requests response
- Test rate limit recovery after timeout
- Test different endpoints have appropriate limits

**Tool:** k6 script with high request rate

#### 5. CORS Testing

**Test Cases:**
- Cross-origin requests from unauthorized domain
- Verify CORS headers
- OPTIONS preflight requests

**Tool:** Browser dev tools + Postman

### GraphQL-Specific Security Tests

#### 1. Query Depth Attack (DoS Risk)

**Attack:**
```graphql
query MaliciousDeepQuery {
  event(id: "1") {
    ticketBatches {
      event {
        ticketBatches {
          event {
            ticketBatches {
              # ... 50 levels deep
            }
          }
        }
      }
    }
  }
}
```

**Test:**
- Send queries with increasing depth (10, 20, 50, 100 levels)
- Measure server response time and CPU usage
- Verify max_depth limit is enforced

**Expected:** Query rejected at configured max_depth

#### 2. Query Complexity Attack

**Attack:**
```graphql
query MaliciousComplexQuery {
  events {
    id name description
    ticketBatches { id price availableTickets }
    # Duplicate fields to increase complexity
    orders { id status totalPrice user { id email } }
    # Request expensive fields
  }
}
```

**Test:**
- Send queries with increasing complexity scores
- Verify max_complexity limit is enforced

**Tool:** GraphQL Cop, manual testing

#### 3. Batch Query Attack

**Attack:**
```json
POST /graphql
[
  { "query": "{ events { id } }" },
  { "query": "{ events { id } }" },
  { "query": "{ events { id } }" },
  // ... 1000 queries
]
```

**Test:**
- Send batched queries (if batching is enabled)
- Verify batch size limits
- Measure DoS potential

**Expected:** Batch limit enforced or batching disabled

#### 4. Introspection Information Disclosure

**Attack:**
```graphql
query IntrospectionQuery {
  __schema {
    types {
      name
      fields {
        name
        type { name }
      }
    }
  }
}
```

**Test:**
- Attempt introspection in production mode
- Verify schema is not exposed

**Expected:** Introspection disabled in production

#### 5. Field Duplication Attack

**Attack:**
```graphql
query FieldDuplication {
  event(id: "1") {
    name
    name
    name
    # ... 1000 times
    description
    description
    # ... 1000 times
  }
}
```

**Test:**
- Send queries with duplicate fields
- Measure server resource consumption

**Tool:** Manual crafted queries

#### 6. Circular Reference Attack

**Attack:**
```graphql
fragment EventFields on Event {
  id
  ticketBatches {
    event {
      ...EventFields
    }
  }
}

query {
  events {
    ...EventFields
  }
}
```

**Test:**
- Send queries with circular fragments
- Verify fragment depth limits

**Tool:** Manual testing

### REST-Specific Security Tests

#### 1. HTTP Method Tampering

**Attack:**
```bash
# Try to delete with GET
GET /api/v1/events/1?_method=DELETE

# Try to modify with GET
GET /api/v1/events/1?_method=PUT&name=Hacked
```

**Test:**
- Attempt CRUD operations with wrong HTTP methods
- Verify method validation

**Expected:** 405 Method Not Allowed

#### 2. Parameter Pollution

**Attack:**
```bash
GET /api/v1/events?id=1&id=2&id=3
GET /api/v1/events?page=1&page=999999
```

**Test:**
- Send duplicate parameters
- Send conflicting parameters
- Verify proper handling

#### 3. Mass Assignment

**Attack:**
```bash
POST /api/v1/users/register
{
  "email": "hacker@evil.com",
  "password": "password",
  "admin": true  # Try to make self admin
}
```

**Test:**
- Attempt to set protected attributes
- Verify strong parameters enforcement

**Expected:** Admin field ignored

#### 4. Information Disclosure via Errors

**Attack:**
```bash
GET /api/v1/events/999999
GET /api/v1/events/'; DROP TABLE events; --
```

**Test:**
- Trigger errors with invalid input
- Verify error messages don't leak sensitive info

**Expected:** Generic error messages in production

#### 5. Pagination Abuse

**Attack:**
```bash
GET /api/v1/events?per_page=999999999
GET /api/v1/events?page=-1
```

**Test:**
- Request excessive page sizes
- Test negative page numbers
- Verify pagination limits

**Expected:** Reasonable max limit enforced

### Security Testing Tools Summary

| Tool | Purpose | Scope |
|------|---------|-------|
| **Brakeman** | Static analysis | Both APIs |
| **bundler-audit** | Dependency vulnerabilities | Both APIs |
| **OWASP ZAP** | Automated web app scanning | Both APIs |
| **GraphQL Cop** | GraphQL security linting | GraphQL only |
| **InQL Scanner** | GraphQL introspection analysis | GraphQL only |
| **Postman/Insomnia** | Manual API testing | Both APIs |
| **sqlmap** | SQL injection testing | Both APIs |
| **k6** | Rate limiting/DoS testing | Both APIs |

### Security Metrics to Collect

| Metric | GraphQL | REST | Comparison |
|--------|---------|------|------------|
| Brakeman warnings | Count | Count | Which has more? |
| Vulnerable gems | Count | Count | Same codebase |
| OWASP ZAP alerts | Count | Count | Which surface area? |
| DoS resistance | Time to crash | Time to crash | Query complexity vs pagination |
| Auth bypass attempts | Success/Fail | Success/Fail | Equal security? |
| Information disclosure | Severity | Severity | Error handling |

---

## Implementation Plan

### Phase 1: Infrastructure Setup (Week 1)
- [ ] Create Docker Compose file for both apps
- [ ] Set up InfluxDB + Grafana stack
- [ ] Configure resource limits (CPU, RAM)
- [ ] Verify both apps run in containers
- [ ] Set up shared PostgreSQL database

### Phase 2: Performance Test Development (Week 2)
- [ ] Write k6 scripts for all 7 scenarios (GraphQL)
- [ ] Write k6 scripts for all 7 scenarios (REST)
- [ ] Create test data seed scripts
- [ ] Set up automated test runner
- [ ] Configure Grafana dashboards

### Phase 3: Performance Test Execution (Week 3)
- [ ] Run all Load Tests (14 tests)
- [ ] Run Stress Tests (6 tests)
- [ ] Run Spike Tests (4 tests)
- [ ] Run Soak Tests (2 tests - may take 2 hours each)
- [ ] Collect and export all metrics
- [ ] Generate comparison charts

### Phase 4: Security Test Development (Week 4)
- [ ] Set up Brakeman, bundler-audit
- [ ] Set up OWASP ZAP
- [ ] Install GraphQL security tools
- [ ] Create manual test cases document
- [ ] Prepare attack payloads

### Phase 5: Security Test Execution (Week 5)
- [ ] Run static analysis tools
- [ ] Run automated security scanners
- [ ] Execute manual attack scenarios
- [ ] Document all findings
- [ ] Create comparison matrix

### Phase 6: Analysis & Documentation (Week 6)
- [ ] Analyze performance data
- [ ] Create thesis charts and graphs
- [ ] Write findings summary
- [ ] Document security comparison
- [ ] Prepare conclusions

---

## Data Analysis Plan

### Statistical Analysis

For each metric, calculate:
- **Mean** - Average performance
- **Median** - Typical performance
- **Standard Deviation** - Variability
- **Min/Max** - Range
- **Percentiles** (p50, p95, p99)

### Comparison Methods

1. **Direct Comparison Charts**
   - Side-by-side bar charts (GraphQL vs REST)
   - Line charts over time
   - Box plots for distribution

2. **Percentage Difference**
   ```
   Difference % = ((GraphQL - REST) / REST) * 100
   ```
   - Positive = GraphQL better
   - Negative = REST better

3. **Statistical Significance**
   - Use t-tests to determine if differences are significant
   - Report p-values in thesis

### Thesis Visualizations

**Charts to create:**
1. Response time comparison (all scenarios)
2. Throughput comparison (requests/sec)
3. Resource usage over time (CPU, Memory)
4. Database queries per request
5. Payload size comparison
6. Error rate under load
7. Scalability curves (performance vs concurrent users)
8. Security vulnerability comparison matrix

---

## Expected Thesis Conclusions

### Performance Findings (Hypothesis)

**GraphQL advantages:**
- 30-50% faster for nested data retrieval
- 40-60% less data transfer for selective fields
- Fewer HTTP requests for complex data needs
- Better for mobile/low-bandwidth scenarios

**REST advantages:**
- 5-10% faster for simple single-resource queries
- More predictable performance (fixed structure)
- Easier HTTP caching

**Similar:**
- Write operations (mutations)
- Database performance (same queries)
- Resource consumption under low load

### Security Findings (Hypothesis)

**GraphQL risks:**
- Query complexity DoS (mitigated with limits)
- Introspection disclosure (mitigated by disabling)
- More complex to secure (learning curve)

**REST risks:**
- Over-fetching = unnecessary data exposure
- More endpoints = larger attack surface
- Parameter pollution easier

**Overall:** Both can be secured equally well with proper implementation

---

## Questions to Answer in Thesis

1. **Performance:**
   - How does response time differ for simple vs complex queries?
   - What is the breaking point for each approach?
   - How does payload size affect performance?
   - Is GraphQL's flexibility worth the overhead?

2. **Security:**
   - Which approach has more attack vectors?
   - Which is easier to secure properly?
   - Are GraphQL-specific attacks a significant risk?
   - How do rate limiting strategies differ?

3. **Developer Experience:**
   - Which is easier to test?
   - Which has better tooling?
   - Which is more maintainable?

4. **Real-World Applicability:**
   - When should you choose GraphQL?
   - When should you choose REST?
   - Can they coexist?

---

## Next Steps

1. Review and approve this testing plan
2. Make any adjustments based on thesis requirements
3. Start with Phase 1: Infrastructure Setup
4. Proceed through phases systematically
5. Document everything for thesis reproducibility

---

**Document Version:** 1.0
**Last Updated:** 2025-11-12
**Author:** Jakub Mikolajczyk
**Thesis:** REST vs GraphQL Performance Comparison in Ruby
