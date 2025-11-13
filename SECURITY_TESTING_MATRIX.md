# Security Testing Comparison Matrix

## Testing Approach

### Phase 1: Automated Scanning (Both APIs)

| Tool | GraphQL | REST | What It Tests | Expected Findings |
|------|---------|------|---------------|-------------------|
| **Brakeman** | ✅ | ✅ | Static code analysis | SQL injection, XSS, mass assignment, auth issues |
| **bundler-audit** | ✅ | ✅ | Vulnerable dependencies | CVEs in gems (should be identical) |
| **RuboCop Security** | ✅ | ✅ | Security linting | Insecure patterns, weak crypto |
| **OWASP ZAP** | ✅ | ✅ | Dynamic vulnerability scanning | OWASP Top 10 issues |

### Phase 2: API-Specific Security Testing

#### GraphQL-Specific Vulnerabilities

| Attack Vector | Tool | Severity | Test Method | Mitigation Check |
|---------------|------|----------|-------------|------------------|
| **Query Depth Attack** | Manual | HIGH | Send 10/20/50/100 level deep queries | Verify `max_depth` enforced |
| **Query Complexity Attack** | GraphQL Cop | HIGH | Send queries with high complexity score | Verify `max_complexity` enforced |
| **Batch Query DoS** | Manual + k6 | MEDIUM | Send 100+ queries in one request | Verify batching disabled/limited |
| **Introspection Disclosure** | GraphQL Cop | MEDIUM | Query `__schema` in production | Verify introspection disabled |
| **Field Duplication** | Manual | LOW | Duplicate fields 1000+ times | Verify field deduplication |
| **Circular Fragments** | Manual | MEDIUM | Create circular fragment references | Verify fragment depth limits |
| **Alias Overloading** | Manual | LOW | Use 1000+ aliases for same field | Verify query validation |
| **Directive Overloading** | Manual | LOW | Abuse @include/@skip directives | Verify directive limits |

**GraphQL Test Script Example:**
```javascript
// graphql_security_tests.js

import http from 'k6/http';
import { check } from 'k6';

export default function() {
  const tests = [
    testQueryDepth(),
    testBatchAttack(),
    testIntrospection(),
    testFieldDuplication(),
  ];
}

function testQueryDepth() {
  // Test 1: Safe query (depth 3)
  const safeQuery = {
    query: `{
      event(id: "1") {
        ticketBatches {
          event { id name }
        }
      }
    }`
  };

  // Test 2: Malicious query (depth 20)
  const deepQuery = {
    query: generateDeepQuery(20)
  };

  const safe = http.post('http://graphql:3000/graphql',
    JSON.stringify(safeQuery),
    { headers: { 'Content-Type': 'application/json' }}
  );

  const malicious = http.post('http://graphql:3000/graphql',
    JSON.stringify(deepQuery),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(safe, {
    'safe query accepted': (r) => r.status === 200,
  });

  check(malicious, {
    'deep query rejected': (r) => r.status === 400 || r.body.includes('exceeds max depth'),
  });
}

function generateDeepQuery(depth) {
  let query = 'query { event(id: "1") { ';
  for (let i = 0; i < depth; i++) {
    query += 'ticketBatches { event { ';
  }
  query += 'id';
  for (let i = 0; i < depth; i++) {
    query += ' } }';
  }
  query += ' } }';
  return query;
}

function testBatchAttack() {
  const batchedQueries = [];
  for (let i = 0; i < 100; i++) {
    batchedQueries.push({
      query: '{ events { id name } }'
    });
  }

  const res = http.post('http://graphql:3000/graphql',
    JSON.stringify(batchedQueries),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(res, {
    'batch query limited': (r) => r.status === 400 || r.status === 429,
  });
}

function testIntrospection() {
  const introspection = {
    query: `{
      __schema {
        types {
          name
          fields { name }
        }
      }
    }`
  };

  const res = http.post('http://graphql:3000/graphql',
    JSON.stringify(introspection),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(res, {
    'introspection disabled in production': (r) =>
      r.status === 400 || !r.body.includes('__schema'),
  });
}

function testFieldDuplication() {
  let fields = '';
  for (let i = 0; i < 100; i++) {
    fields += ' id name description ';
  }

  const query = {
    query: `{ event(id: "1") { ${fields} } }`
  };

  const res = http.post('http://graphql:3000/graphql',
    JSON.stringify(query),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(res, {
    'field duplication handled': (r) => r.status === 200,
    'response time reasonable': (r) => r.timings.duration < 1000,
  });
}
```

#### REST-Specific Vulnerabilities

| Attack Vector | Tool | Severity | Test Method | Mitigation Check |
|---------------|------|----------|-------------|------------------|
| **HTTP Method Tampering** | Postman | MEDIUM | GET with ?_method=DELETE | Verify method validation |
| **Parameter Pollution** | Manual | MEDIUM | Send duplicate parameters | Verify proper parsing |
| **Mass Assignment** | Manual | HIGH | Send admin=true in registration | Verify strong parameters |
| **Pagination Abuse** | Manual | LOW | Request per_page=999999 | Verify max limit enforced |
| **Verbose Error Messages** | OWASP ZAP | MEDIUM | Trigger errors, check stack traces | Verify generic errors in prod |
| **CORS Misconfiguration** | Browser DevTools | MEDIUM | Cross-origin requests | Verify CORS whitelist |
| **Cache Poisoning** | Manual | LOW | Manipulate cache headers | Verify cache validation |

**REST Test Script Example:**
```javascript
// rest_security_tests.js

import http from 'k6/http';
import { check } from 'k6';

export default function() {
  testMethodTampering();
  testParameterPollution();
  testMassAssignment();
  testPaginationAbuse();
}

function testMethodTampering() {
  // Try to delete via GET
  const res1 = http.get('http://rest:3001/api/v1/events/1?_method=DELETE', {
    headers: { 'Authorization': 'Bearer VALID_TOKEN' }
  });

  check(res1, {
    'method tampering blocked': (r) => r.status !== 200,
  });

  // Try to update via GET
  const res2 = http.get('http://rest:3001/api/v1/events/1?_method=PUT&name=Hacked');

  check(res2, {
    'method tampering blocked': (r) => r.status !== 200,
  });
}

function testParameterPollution() {
  const res = http.get('http://rest:3001/api/v1/events?id=1&id=2&id=3');

  check(res, {
    'parameter pollution handled safely': (r) => r.status === 200,
    'returns consistent result': (r) => {
      // Should pick first, last, or reject - but consistently
      return r.status === 200 || r.status === 400;
    }
  });
}

function testMassAssignment() {
  const maliciousRegistration = {
    email: 'hacker@evil.com',
    password: 'password123',
    first_name: 'Hacker',
    last_name: 'McHack',
    admin: true  // Trying to make self admin!
  };

  const res = http.post('http://rest:3001/api/v1/users/register',
    JSON.stringify(maliciousRegistration),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(res, {
    'mass assignment blocked': (r) => {
      const body = JSON.parse(r.body);
      return !body.user || body.user.admin === false;
    }
  });
}

function testPaginationAbuse() {
  const res1 = http.get('http://rest:3001/api/v1/events?per_page=999999');
  const res2 = http.get('http://rest:3001/api/v1/events?page=-1');

  check(res1, {
    'excessive page size limited': (r) => {
      const body = JSON.parse(r.body);
      return body.data.length <= 100; // Assuming max 100
    }
  });

  check(res2, {
    'negative page rejected': (r) => r.status === 400,
  });
}
```

### Phase 3: Common Vulnerabilities (Both APIs)

#### Authentication & Authorization Tests

```javascript
// auth_tests.js

const authTests = {
  graphql: 'http://graphql:3000/graphql',
  rest: 'http://rest:3001/api/v1'
};

export default function() {
  testNoToken();
  testInvalidToken();
  testExpiredToken();
  testUnauthorizedAccess();
}

function testNoToken() {
  // GraphQL
  const gql = http.post(authTests.graphql,
    JSON.stringify({ query: '{ currentUser { id } }' }),
    { headers: { 'Content-Type': 'application/json' }}
  );

  // REST
  const rest = http.get(`${authTests.rest}/current_user`);

  check(gql, { 'GraphQL rejects no token': (r) => r.status === 401 });
  check(rest, { 'REST rejects no token': (r) => r.status === 401 });
}

function testInvalidToken() {
  const invalidToken = 'Bearer invalid.token.here';

  // GraphQL
  const gql = http.post(authTests.graphql,
    JSON.stringify({ query: '{ currentUser { id } }' }),
    { headers: {
      'Content-Type': 'application/json',
      'Authorization': invalidToken
    }}
  );

  // REST
  const rest = http.get(`${authTests.rest}/current_user`, {
    headers: { 'Authorization': invalidToken }
  });

  check(gql, { 'GraphQL rejects invalid token': (r) => r.status === 401 });
  check(rest, { 'REST rejects invalid token': (r) => r.status === 401 });
}

function testUnauthorizedAccess() {
  const userToken = 'Bearer USER_TOKEN_HERE'; // Non-admin user

  // GraphQL - try to create event (admin only)
  const gql = http.post(authTests.graphql,
    JSON.stringify({
      query: `mutation {
        createEvent(input: {
          name: "Hacked Event"
          description: "Test"
          place: "Test"
          date: "2025-12-01"
          category: "music"
        }) { event { id } }
      }`
    }),
    { headers: {
      'Content-Type': 'application/json',
      'Authorization': userToken
    }}
  );

  // REST - try to create event (admin only)
  const rest = http.post(`${authTests.rest}/events`,
    JSON.stringify({
      name: "Hacked Event",
      description: "Test",
      place: "Test",
      date: "2025-12-01",
      category: "music"
    }),
    { headers: {
      'Content-Type': 'application/json',
      'Authorization': userToken
    }}
  );

  check(gql, { 'GraphQL blocks non-admin': (r) => r.status === 403 || r.body.includes('Admin') });
  check(rest, { 'REST blocks non-admin': (r) => r.status === 403 });
}
```

#### Input Validation Tests

```javascript
// input_validation_tests.js

const sqlInjectionPayloads = [
  "'; DROP TABLE users; --",
  "1' OR '1'='1",
  "admin'--",
  "' UNION SELECT NULL--"
];

const xssPayloads = [
  "<script>alert('XSS')</script>",
  "<img src=x onerror=alert('XSS')>",
  "javascript:alert('XSS')",
  "<svg/onload=alert('XSS')>"
];

export default function() {
  sqlInjectionPayloads.forEach(payload => {
    testSQLInjection(payload);
  });

  xssPayloads.forEach(payload => {
    testXSS(payload);
  });
}

function testSQLInjection(payload) {
  // GraphQL
  const gql = http.post('http://graphql:3000/graphql',
    JSON.stringify({
      query: `mutation {
        register(input: {
          email: "${payload}"
          password: "test123"
          firstName: "Test"
          lastName: "User"
        }) { token }
      }`
    }),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(gql, {
    'GraphQL blocks SQL injection': (r) =>
      r.status === 400 || r.body.includes('validation') || r.body.includes('error')
  });

  // REST
  const rest = http.post('http://rest:3001/api/v1/users/register',
    JSON.stringify({
      email: payload,
      password: "test123",
      first_name: "Test",
      last_name: "User"
    }),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(rest, {
    'REST blocks SQL injection': (r) =>
      r.status === 400 || r.body.includes('validation') || r.body.includes('error')
  });
}

function testXSS(payload) {
  // Test in event creation (requires admin token)
  const adminToken = 'Bearer ADMIN_TOKEN_HERE';

  // GraphQL
  const gql = http.post('http://graphql:3000/graphql',
    JSON.stringify({
      query: `mutation {
        createEvent(input: {
          name: "${payload}"
          description: "${payload}"
          place: "Test"
          date: "2025-12-01"
          category: "music"
        }) { event { id name } }
      }`
    }),
    { headers: {
      'Content-Type': 'application/json',
      'Authorization': adminToken
    }}
  );

  check(gql, {
    'GraphQL sanitizes XSS': (r) => {
      // Should either reject or escape
      return r.status === 400 || !r.body.includes('<script>');
    }
  });
}
```

#### Rate Limiting Tests

```javascript
// rate_limiting_tests.js

import { sleep } from 'k6';

export const options = {
  scenarios: {
    graphql_rate_limit: {
      executor: 'constant-arrival-rate',
      rate: 200, // 200 requests per second
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 10,
      exec: 'testGraphQLRateLimit',
    },
    rest_rate_limit: {
      executor: 'constant-arrival-rate',
      rate: 200,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 10,
      exec: 'testRESTRateLimit',
    },
  },
};

export function testGraphQLRateLimit() {
  const res = http.post('http://graphql:3000/graphql',
    JSON.stringify({ query: '{ events { id } }' }),
    { headers: { 'Content-Type': 'application/json' }}
  );

  check(res, {
    'request completed': (r) => r.status !== 0,
    'not rate limited': (r) => r.status !== 429,
  });

  if (res.status === 429) {
    console.log('GraphQL rate limit triggered');
  }
}

export function testRESTRateLimit() {
  const res = http.get('http://rest:3001/api/v1/events');

  check(res, {
    'request completed': (r) => r.status !== 0,
    'not rate limited': (r) => r.status !== 429,
  });

  if (res.status === 429) {
    console.log('REST rate limit triggered');
  }
}
```

## Security Comparison Matrix

### Vulnerability Surface Area

| Category | GraphQL | REST | Winner |
|----------|---------|------|--------|
| **Number of Endpoints** | 1 (`/graphql`) | ~20+ | GraphQL ✅ (smaller surface) |
| **Query Complexity Control** | Required | Not applicable | - |
| **Over-fetching Risk** | Low (client controls) | High (fixed responses) | GraphQL ✅ |
| **Information Disclosure** | Higher (introspection) | Lower | REST ✅ |
| **DoS Risk** | Higher (complex queries) | Lower | REST ✅ |
| **Learning Curve for Security** | Higher | Lower | REST ✅ |

### Expected Security Test Results

| Test | GraphQL Expected | REST Expected | Notes |
|------|------------------|---------------|-------|
| **Brakeman Warnings** | 5-10 | 5-10 | Similar (same codebase) |
| **SQL Injection** | Both safe | Both safe | Rails protects both |
| **XSS** | Both safe | Both safe | Rails escaping |
| **Auth Bypass** | None | None | Same JWT implementation |
| **Rate Limiting** | 429 after limit | 429 after limit | Both should have |
| **DoS Resistance** | Fails with deep queries (if not limited) | Fails with pagination abuse | Different attack vectors |
| **Info Disclosure** | Risk if introspection on | Risk with verbose errors | Different risks |

## Thesis Security Conclusions

### Security Comparison Summary

**GraphQL Security:**
- ✅ Smaller attack surface (single endpoint)
- ✅ Better control over data exposure (no over-fetching)
- ❌ More complex security requirements (depth, complexity limits)
- ❌ Introspection can leak schema information
- ❌ Query complexity attacks possible

**REST Security:**
- ✅ Simpler to secure (well-understood)
- ✅ Better HTTP caching (less DoS risk)
- ✅ Established security patterns
- ❌ Larger attack surface (many endpoints)
- ❌ Over-fetching exposes unnecessary data
- ❌ Pagination abuse possible

**Overall Verdict:**
Both can be equally secure when properly implemented. GraphQL requires more sophisticated security measures (query limits, introspection control), while REST relies on traditional web security best practices.

## Next Steps

1. Set up security testing environment
2. Run automated scanners (Brakeman, OWASP ZAP)
3. Execute manual attack scenarios
4. Document all findings
5. Create comparison charts for thesis
6. Write security recommendations

---

**Last Updated:** 2025-11-12
