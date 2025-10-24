# Security Middleware Documentation

**Date:** 2025-10-24
**Status:** Implemented - Phase 2.4
**Component:** Backend Security Layer

## Overview

This document describes the security middleware implemented in the backend application to protect against common web vulnerabilities and attacks. The security layer includes **rate limiting**, **security headers**, **CORS**, and **distributed tracing** with security context.

## Architecture

```
┌──────────┐     ┌────────────────┐     ┌──────────┐     ┌─────────┐
│  Client  │────▶│   Middleware   │────▶│  Router  │────▶│ Handler │
│          │     │   Stack        │     │          │     │         │
└──────────┘     └────────────────┘     └──────────┘     └─────────┘
                        │
                        ├─ Request ID
                        ├─ Tracing (OpenTelemetry)
                        ├─ Security Headers
                        ├─ Logging
                        ├─ Panic Recovery
                        ├─ Rate Limiting
                        ├─ CORS
                        └─ Timeout (30s)
```

## Middleware Components

### 1. Rate Limiting

**File:** `backend/internal/http/middleware/ratelimit.go`

**Purpose:** Protect against DoS/DDoS attacks by limiting requests per IP address.

**Configuration:**
- **Rate:** 100 requests per second per IP
- **Burst:** 200 requests (allows temporary spikes)
- **Algorithm:** Token bucket (golang.org/x/time/rate)
- **Cleanup:** Automatic memory cleanup every 5 minutes

**Features:**
- ✅ IP-based rate limiting
- ✅ Support for `X-Forwarded-For` header (proxy/load balancer)
- ✅ Support for `X-Real-IP` header
- ✅ Independent limits per IP address
- ✅ Automatic limiter cleanup to prevent memory leaks
- ✅ HTTP 429 (Too Many Requests) response when exceeded

**Usage:**
```go
import (
    "golang.org/x/time/rate"
    custommw "github.com/soft-yt/app-base-go-react/internal/http/middleware"
)

// Create rate limiter: 100 req/sec per IP, burst of 200
rateLimiter := custommw.NewIPRateLimiter(rate.Limit(100), 200)
rateLimiter.StartCleanup() // Start cleanup goroutine

// Apply middleware
router.Use(rateLimiter.RateLimit())
```

**Example Response (Rate Limit Exceeded):**
```http
HTTP/1.1 429 Too Many Requests
Content-Type: text/plain

Rate limit exceeded. Please try again later.
```

**Tuning:**
```go
// High traffic API
rateLimiter := NewIPRateLimiter(rate.Limit(1000), 2000)

// Low traffic API
rateLimiter := NewIPRateLimiter(rate.Limit(10), 20)

// Per-user rate limiting (requires authentication)
// Implement custom getLimiter() based on user ID instead of IP
```

---

### 2. Security Headers

**File:** `backend/internal/http/middleware/security.go`

**Purpose:** Implement OWASP security best practices through HTTP headers.

#### 2.1. SecurityHeaders (Full Set)

For HTML pages and applications serving content to browsers.

**Headers Applied:**

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME type sniffing |
| `X-XSS-Protection` | `1; mode=block` | Enable XSS filter (legacy browsers) |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Enforce HTTPS (1 year) |
| `Content-Security-Policy` | (see below) | Prevent XSS/injection attacks |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer information |
| `Permissions-Policy` | (see below) | Disable dangerous browser features |

**Content Security Policy (CSP):**
```
default-src 'self';
script-src 'self' 'unsafe-inline' 'unsafe-eval';
style-src 'self' 'unsafe-inline';
img-src 'self' data: https:;
font-src 'self';
connect-src 'self';
frame-ancestors 'none';
base-uri 'self';
form-action 'self'
```

**Permissions Policy:**
```
geolocation=(), microphone=(), camera=(), payment=(),
usb=(), magnetometer=(), gyroscope=(), accelerometer=()
```

**Usage:**
```go
router.Use(custommw.SecurityHeaders)
```

#### 2.2. APISecurityHeaders (Lightweight)

For REST API endpoints (no CSP needed).

**Headers Applied:**
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Cache-Control: no-store, no-cache, must-revalidate, private`
- `Pragma: no-cache`
- `Expires: 0`

**Usage:**
```go
router.Use(custommw.APISecurityHeaders)
```

**Server Fingerprinting Prevention:**
Both middleware variants automatically remove:
- `Server` header
- `X-Powered-By` header

---

### 3. CORS (Cross-Origin Resource Sharing)

**File:** `backend/internal/http/middleware/cors.go`

**Purpose:** Control which origins can access the API.

**Current Configuration:**
```go
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

**⚠️ Production Recommendation:**
```go
// Replace * with specific origins
w.Header().Set("Access-Control-Allow-Origin", "https://app.example.com")

// Or implement dynamic origin checking
allowedOrigins := []string{
    "https://app.example.com",
    "https://admin.example.com",
}
```

---

### 4. Request Tracing

**File:** `backend/internal/http/middleware/tracing.go`

**Purpose:** Distributed tracing with OpenTelemetry for security auditing.

**Security Features:**
- Trace ID in response headers (`X-Trace-ID`)
- Request method and path tracking
- Status code tracking
- Client IP tracking
- User agent tracking
- Error tracking

**Usage:**
```go
router.Use(custommw.Tracing)
```

**Example Response Headers:**
```http
X-Trace-ID: 4bf92f3577b34da6a3ce929d0e0e4736
X-Span-ID: 00f067aa0ba902b7
```

---

## Middleware Stack Order

**IMPORTANT:** Middleware order matters! Current optimal order:

```go
r.Use(middleware.RequestID)           // 1. Generate request ID
r.Use(custommw.Tracing)              // 2. Start distributed trace
r.Use(custommw.APISecurityHeaders)   // 3. Add security headers
r.Use(custommw.Logger)               // 4. Log request (has req ID + trace)
r.Use(middleware.Recoverer)          // 5. Catch panics
r.Use(rateLimiter.RateLimit())       // 6. Rate limiting
r.Use(custommw.CORS)                 // 7. CORS headers
r.Use(middleware.Timeout(30s))       // 8. Request timeout
```

**Rationale:**
1. **RequestID first** - needed by all other middleware
2. **Tracing second** - creates span for entire request
3. **Security headers** - apply before any processing
4. **Logger** - can log security headers and trace context
5. **Recoverer** - catch panics from all subsequent middleware
6. **Rate limiting** - reject overload before expensive operations
7. **CORS** - apply CORS after rate limiting
8. **Timeout last** - wrap actual request processing

---

## Security Testing

### Unit Tests

**File:** `backend/internal/http/middleware/middleware_test.go`

**Coverage:**
- ✅ Rate limiting: allows within limit
- ✅ Rate limiting: blocks over limit
- ✅ Rate limiting: different IPs have independent limits
- ✅ Rate limiting: recovers after wait time
- ✅ Rate limiting: respects X-Forwarded-For header
- ✅ Security headers: adds all required headers
- ✅ API security headers: adds API-specific headers
- ✅ Security headers: removes server identification

**Run tests:**
```bash
cd backend
go test ./internal/http/middleware/... -v
```

### Integration Tests

Test rate limiting in real environment:

```bash
# Install hey (HTTP load generator)
go install github.com/rakyll/hey@latest

# Test rate limiting (should get 429 responses)
hey -n 300 -c 10 http://localhost:8080/api/v1/config

# Expected: ~100-200 successful, rest 429 Too Many Requests
```

### Security Scanning

See `.github/workflows/security.yml` for automated security scanning:

- ✅ **gosec** - Go security scanner
- ✅ **CodeQL** - Static code analysis
- ✅ **Trivy** - Container vulnerability scanner
- ✅ **OWASP Dependency Check** - Dependency vulnerabilities
- ✅ **Gitleaks** - Secret scanning

---

## OWASP Top 10 Coverage

| OWASP Top 10 2021 | Mitigation | Status |
|-------------------|------------|--------|
| A01:2021 – Broken Access Control | Rate limiting, authentication required | ⚠️ Partial |
| A02:2021 – Cryptographic Failures | HSTS enforces HTTPS | ✅ Covered |
| A03:2021 – Injection | CSP, input validation needed | ⚠️ Partial |
| A04:2021 – Insecure Design | Security middleware, SOPS | ✅ Covered |
| A05:2021 – Security Misconfiguration | Security headers, no server info | ✅ Covered |
| A06:2021 – Vulnerable Components | Dependency scanning, Trivy | ✅ Covered |
| A07:2021 – Identification/Authentication | To be implemented | ❌ TODO |
| A08:2021 – Software/Data Integrity | Code signing, SOPS | ✅ Covered |
| A09:2021 – Security Logging Failures | OpenTelemetry tracing, logging | ✅ Covered |
| A10:2021 – Server-Side Request Forgery | To be implemented | ❌ TODO |

---

## Best Practices

### ✅ DO

- ✅ Use rate limiting on all public endpoints
- ✅ Apply security headers to all responses
- ✅ Monitor rate limit hits (check logs/metrics)
- ✅ Review CSP policy for your specific frontend needs
- ✅ Use HTTPS in production (HSTS requires it)
- ✅ Implement authentication/authorization
- ✅ Log security events (rate limit violations, etc.)
- ✅ Regularly update dependencies (npm audit, go mod tidy)
- ✅ Run security scans in CI/CD

### ❌ DON'T

- ❌ Don't disable security headers in production
- ❌ Don't use `Access-Control-Allow-Origin: *` in production
- ❌ Don't expose detailed error messages to clients
- ❌ Don't commit secrets (use SOPS - see SOPS-SECRETS-MANAGEMENT.md)
- ❌ Don't skip security updates
- ❌ Don't rely solely on client-side validation

---

## Configuration

### Environment Variables

Rate limiting can be configured via environment variables:

```bash
# Rate limiter settings (to be implemented)
RATE_LIMIT_REQUESTS_PER_SECOND=100
RATE_LIMIT_BURST=200
RATE_LIMIT_CLEANUP_INTERVAL=5m
```

### Production Recommendations

**High-traffic production:**
```go
// Increase limits for production
rateLimiter := NewIPRateLimiter(rate.Limit(1000), 2000)

// Use distributed rate limiting (Redis)
// This requires implementing a Redis-backed rate limiter
```

**Strict CORS:**
```go
// Whitelist specific origins
func CORS(allowedOrigins []string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            origin := r.Header.Get("Origin")
            if contains(allowedOrigins, origin) {
                w.Header().Set("Access-Control-Allow-Origin", origin)
            }
            // ... rest of CORS logic
        })
    }
}
```

**Stricter CSP:**
```
Content-Security-Policy: default-src 'self';
                         script-src 'self' https://cdn.example.com;
                         style-src 'self' https://cdn.example.com;
                         img-src 'self' https://images.example.com data:;
                         connect-src 'self' https://api.example.com;
                         frame-ancestors 'none';
                         base-uri 'self';
                         form-action 'self'
```

---

## Monitoring

### Metrics to Track

1. **Rate Limit Violations:**
   ```
   rate_limit_violations_total{ip="x.x.x.x"}
   ```

2. **Request Latency by Middleware:**
   ```
   http_middleware_duration_seconds{middleware="rate_limit"}
   ```

3. **Security Header Coverage:**
   ```
   http_security_headers_present{header="X-Frame-Options"}
   ```

### Logging

All security events are logged with structured logging:

```json
{
  "time": "2025-10-24T12:00:00Z",
  "level": "WARN",
  "msg": "Rate limit exceeded",
  "ip": "203.0.113.1",
  "path": "/api/v1/items",
  "trace_id": "4bf92f3577b34da6"
}
```

---

## Troubleshooting

### Rate Limit False Positives

**Problem:** Legitimate users getting rate limited

**Solutions:**
1. Increase burst size for APIs with legitimate bursts
2. Implement per-user rate limiting (requires auth)
3. Whitelist known IPs (office, monitoring tools)

```go
// Whitelist specific IPs
if ip == "192.168.1.1" {
    next.ServeHTTP(w, r)
    return
}
```

### CSP Violations

**Problem:** Content blocked by CSP policy

**Solutions:**
1. Check browser console for CSP violation reports
2. Adjust CSP policy to allow required sources
3. Use CSP report-only mode during development:

```go
w.Header().Set("Content-Security-Policy-Report-Only", csp)
```

### CORS Issues

**Problem:** Browser blocks cross-origin requests

**Solutions:**
1. Check browser console for CORS errors
2. Verify origin is in allowed list
3. Ensure preflight (OPTIONS) requests are handled
4. Check credentials flag: `Access-Control-Allow-Credentials`

---

## Related Documentation

- [SOPS Secrets Management](./SOPS-SECRETS-MANAGEMENT.md)
- [Architecture Overview](./architecture-overview.md)
- [CI/CD Pipeline](./ci-cd-pipeline.md)
- [Definition of Done](./definition-of-done.md)

---

## References

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Content Security Policy (CSP)](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [HTTP Strict Transport Security (HSTS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Strict-Transport-Security)
- [golang.org/x/time/rate](https://pkg.go.dev/golang.org/x/time/rate)

---

**Document Version:** 1.0
**Last Updated:** 2025-10-24
**Maintained By:** Platform Team
