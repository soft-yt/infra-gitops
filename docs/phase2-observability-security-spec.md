# Phase 2: Observability, Security & Secrets Management - DDD/TDD Specification

**Status:** Active | **Phase:** 2/5 | **Builds On:** Phase 1 (73% coverage - COMPLETED)

## 1. Executive Summary

This specification defines the implementation of **Observability Stack, Security Features, and Secrets Management** for the soft-yt platform following Infrastructure-as-Code and GitOps best practices.

**Current State (End of Phase 1):**
- Clean architecture: Handler → Service → Repository → PostgreSQL
- Test coverage: 73% (91% of target)
- Basic logging: stdout/stderr without structure
- Secrets: Hardcoded in config or environment variables
- No metrics or tracing
- No rate limiting or input sanitization
- No ingress controller or TLS management
- Images not signed

**Target State (End of Phase 2):**
- Observability: Prometheus + Grafana + Loki + Tempo integrated
- Structured logging: zerolog or slog with correlation IDs
- Metrics: Backend `/metrics` endpoint, frontend browser metrics
- Tracing: OpenTelemetry SDK instrumentation
- Secrets: SOPS for GitOps manifests, Vault for runtime secrets
- Security: Rate limiting, input sanitization, OWASP testing
- Ingress: Production-ready controller with TLS (cert-manager)
- Image Security: Cosign signing, SBOM generation

---

## 2. Domain Model

### 2.1. Bounded Context: Platform Observability

**Aggregates:**
- `MetricsCollector` - Collects and exposes application metrics
- `TracingContext` - Manages distributed trace propagation
- `LogEntry` - Structured log with correlation

**Value Objects:**
- `TraceID` - UUID for distributed tracing
- `SpanID` - Unique identifier for trace span
- `MetricLabel` - Key-value pair for metric dimensions
- `LogLevel` - Enum: DEBUG, INFO, WARN, ERROR

**Domain Services:**
- `ObservabilityService` - Coordinates metrics/logs/traces
- `CorrelationService` - Manages request correlation IDs

### 2.2. Bounded Context: Secrets Management

**Aggregates:**
- `Secret` - Encrypted secret in GitOps (SOPS)
- `VaultSecret` - Runtime secret from HashiCorp Vault
- `EncryptionKey` - SOPS age key for encryption

**Value Objects:**
- `SecretPath` - Vault path (e.g., `secret/data/app/db`)
- `EncryptedValue` - SOPS-encrypted YAML value

**Domain Services:**
- `EncryptionService` - SOPS encryption/decryption
- `VaultService` - Runtime secret retrieval

### 2.3. Bounded Context: Security

**Aggregates:**
- `RateLimiter` - Token bucket rate limiting per IP/user
- `SecurityPolicy` - Input validation and sanitization rules
- `ImageSignature` - Cosign signature verification

**Value Objects:**
- `IPAddress` - IPv4/IPv6 address for rate limiting
- `RateLimit` - Requests per time window
- `SanitizationRule` - XSS/injection prevention pattern

**Domain Services:**
- `RateLimitService` - Distributed rate limiting
- `SanitizationService` - Input cleaning middleware

---

## 3. Secrets Management Specification

### 3.1. SOPS Integration (GitOps Encryption)

#### 3.1.1. SOPS Configuration

**File:** `infra-gitops/secrets/.sops.yaml`

```yaml
creation_rules:
  # Development environment
  - path_regex: apps/.*/overlays/dev/.*\.enc\.yaml$
    age: >-
      age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqydev

  # Production environment
  - path_regex: apps/.*/overlays/prod/.*\.enc\.yaml$
    age: >-
      age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyPROD

  # Cluster-specific secrets
  - path_regex: clusters/yc-dev/.*\.enc\.yaml$
    age: >-
      age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyYC

  - path_regex: clusters/vk-prod/.*\.enc\.yaml$
    age: >-
      age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyVK

  - path_regex: clusters/onprem-lab/.*\.enc\.yaml$
    age: >-
      age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyONPREM
```

#### 3.1.2. Secret Example (Encrypted)

**File:** `infra-gitops/apps/webapp/overlays/dev/secrets.enc.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-secrets
  namespace: default
type: Opaque
stringData:
  DB_PASSWORD: ENC[AES256_GCM,data:8/2rT4...,tag:XyZ...]
  API_KEY: ENC[AES256_GCM,data:mNpQr3...,tag:AbC...]
  JWT_SECRET: ENC[AES256_GCM,data:7KlMn8...,tag:DeF...]
sops:
  kms: []
  gcp_kms: []
  azure_kv: []
  hc_vault: []
  age:
    - recipient: age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyDEV
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSB...
        -----END AGE ENCRYPTED FILE-----
  lastmodified: "2025-10-24T09:00:00Z"
  mac: ENC[AES256_GCM,data:abc123...,tag:xyz789...]
  version: 3.8.1
```

#### 3.1.3. Encryption/Decryption Workflow

**Encryption Command:**
```bash
# Install SOPS
brew install sops age  # macOS
# OR
curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
chmod +x sops-v3.8.1.linux.amd64 && sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops

# Generate age key pair
age-keygen -o keys/dev.txt
# Output: Public key: age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyDEV

# Encrypt secret
SOPS_AGE_KEY_FILE=keys/dev.txt sops -e apps/webapp/overlays/dev/secrets.yaml > apps/webapp/overlays/dev/secrets.enc.yaml

# Decrypt for local development
SOPS_AGE_KEY_FILE=keys/dev.txt sops -d apps/webapp/overlays/dev/secrets.enc.yaml > /tmp/secrets.yaml
```

**CI/CD Integration (GitHub Actions):**
```yaml
# .github/workflows/deploy.yml
- name: Decrypt secrets
  env:
    SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_PRIVATE_KEY }}
  run: |
    echo "$SOPS_AGE_KEY" > /tmp/age-key.txt
    export SOPS_AGE_KEY_FILE=/tmp/age-key.txt
    sops -d apps/webapp/overlays/${{ env.ENVIRONMENT }}/secrets.enc.yaml > secrets-plain.yaml
    # Use secrets-plain.yaml for deployment
    rm /tmp/age-key.txt secrets-plain.yaml
```

#### 3.1.4. Key Management Strategy

**Key Storage:**
- Development keys: Shared in team password manager (1Password/Bitwarden)
- Production keys: Hardware Security Module (HSM) or cloud KMS
- CI/CD keys: GitHub Secrets (rotate every 90 days)

**Key Rotation Procedure:**
```bash
# 1. Generate new key
age-keygen -o keys/dev-new.txt

# 2. Add new key to .sops.yaml (keep old key for transition)
creation_rules:
  - path_regex: apps/.*/overlays/dev/.*\.enc\.yaml$
    age: >-
      age1NEW_PUBLIC_KEY,
      age1OLD_PUBLIC_KEY

# 3. Re-encrypt all secrets
find apps -name "*.enc.yaml" -exec sops updatekeys -y {} \;

# 4. Remove old key from .sops.yaml after 30 days
# 5. Revoke old private keys
```

**Automated Rotation (Quarterly):**
- Scheduled GitHub Action job
- Generates new keys
- Re-encrypts all secrets
- Creates PR with updated manifests
- Notifies team to update local keys

---

### 3.2. HashiCorp Vault Integration (Runtime Secrets)

#### 3.2.1. Vault Deployment

**File:** `infra-gitops/apps/vault/base/statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: vault
spec:
  serviceName: vault
  replicas: 3
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      containers:
      - name: vault
        image: hashicorp/vault:1.15.4
        ports:
        - containerPort: 8200
          name: api
        - containerPort: 8201
          name: cluster
        env:
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        - name: VAULT_API_ADDR
          value: "http://vault.vault.svc.cluster.local:8200"
        - name: VAULT_CLUSTER_ADDR
          value: "https://$(POD_IP):8201"
        volumeMounts:
        - name: config
          mountPath: /vault/config
        - name: data
          mountPath: /vault/data
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true
            port: 8200
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true&perfstandbyok=true
            port: 8200
          initialDelaySeconds: 10
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: vault-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 10Gi
```

#### 3.2.2. Vault Configuration

**File:** `infra-gitops/apps/vault/base/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  vault.hcl: |
    ui = true

    listener "tcp" {
      address = "[::]:8200"
      cluster_address = "[::]:8201"
      tls_disable = true  # Use Istio/Traefik for TLS termination
    }

    storage "raft" {
      path = "/vault/data"

      retry_join {
        leader_api_addr = "http://vault-0.vault.vault.svc.cluster.local:8200"
      }
      retry_join {
        leader_api_addr = "http://vault-1.vault.vault.svc.cluster.local:8200"
      }
      retry_join {
        leader_api_addr = "http://vault-2.vault.vault.svc.cluster.local:8200"
      }
    }

    service_registration "kubernetes" {}

    api_addr = "http://vault.vault.svc.cluster.local:8200"
    cluster_addr = "https://vault:8201"
```

#### 3.2.3. Kubernetes Auth Configuration

**Initialization Script:**
```bash
#!/bin/bash
# scripts/vault-init.sh

# Initialize Vault (run once per cluster)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-keys.json

# Unseal Vault on each pod
for i in 0 1 2; do
  kubectl exec -n vault vault-$i -- vault operator unseal $(jq -r '.unseal_keys_b64[0]' vault-keys.json)
  kubectl exec -n vault vault-$i -- vault operator unseal $(jq -r '.unseal_keys_b64[1]' vault-keys.json)
  kubectl exec -n vault vault-$i -- vault operator unseal $(jq -r '.unseal_keys_b64[2]' vault-keys.json)
done

# Login with root token
export VAULT_TOKEN=$(jq -r '.root_token' vault-keys.json)
kubectl exec -n vault vault-0 -- vault login $VAULT_TOKEN

# Enable Kubernetes auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure Kubernetes auth
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy for webapp
kubectl exec -n vault vault-0 -- vault policy write webapp - <<EOF
path "secret/data/webapp/*" {
  capabilities = ["read", "list"]
}
EOF

# Create Kubernetes role
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/webapp \
  bound_service_account_names=webapp \
  bound_service_account_namespaces=default \
  policies=webapp \
  ttl=24h
```

#### 3.2.4. Application Integration (Go Backend)

**File:** `backend/internal/vault/client.go`

```go
package vault

import (
    "context"
    "fmt"
    "log/slog"
    "os"

    vault "github.com/hashicorp/vault/api"
    auth "github.com/hashicorp/vault/api/auth/kubernetes"
)

type Client struct {
    client *vault.Client
    logger *slog.Logger
}

// NewClient creates Vault client with Kubernetes auth
func NewClient(logger *slog.Logger) (*Client, error) {
    config := vault.DefaultConfig()
    config.Address = os.Getenv("VAULT_ADDR")
    if config.Address == "" {
        config.Address = "http://vault.vault.svc.cluster.local:8200"
    }

    client, err := vault.NewClient(config)
    if err != nil {
        return nil, fmt.Errorf("failed to create vault client: %w", err)
    }

    // Kubernetes auth
    k8sAuth, err := auth.NewKubernetesAuth(
        "webapp", // role name
        auth.WithServiceAccountTokenPath("/var/run/secrets/kubernetes.io/serviceaccount/token"),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create k8s auth: %w", err)
    }

    authInfo, err := client.Auth().Login(context.Background(), k8sAuth)
    if err != nil {
        return nil, fmt.Errorf("failed to login to vault: %w", err)
    }

    if authInfo == nil {
        return nil, fmt.Errorf("no auth info returned from vault")
    }

    logger.Info("Successfully authenticated with Vault",
        "token_ttl", authInfo.Auth.LeaseDuration,
        "renewable", authInfo.Auth.Renewable,
    )

    return &Client{
        client: client,
        logger: logger,
    }, nil
}

// GetSecret retrieves a secret from Vault
func (c *Client) GetSecret(ctx context.Context, path string) (map[string]interface{}, error) {
    secret, err := c.client.KVv2("secret").Get(ctx, path)
    if err != nil {
        c.logger.Error("Failed to read secret from Vault",
            "path", path,
            "error", err,
        )
        return nil, fmt.Errorf("failed to read secret %s: %w", path, err)
    }

    c.logger.Debug("Successfully retrieved secret from Vault",
        "path", path,
        "version", secret.VersionMetadata.Version,
    )

    return secret.Data, nil
}

// GetSecretField retrieves a specific field from a secret
func (c *Client) GetSecretField(ctx context.Context, path, field string) (string, error) {
    data, err := c.GetSecret(ctx, path)
    if err != nil {
        return "", err
    }

    value, ok := data[field].(string)
    if !ok {
        return "", fmt.Errorf("field %s not found in secret %s", field, path)
    }

    return value, nil
}

// RenewToken renews the Vault token (should be called periodically)
func (c *Client) RenewToken(ctx context.Context) error {
    _, err := c.client.Auth().Token().RenewSelf(0)
    if err != nil {
        c.logger.Error("Failed to renew Vault token", "error", err)
        return fmt.Errorf("failed to renew token: %w", err)
    }

    c.logger.Info("Successfully renewed Vault token")
    return nil
}
```

**Usage in main.go:**
```go
// Initialize Vault client
vaultClient, err := vault.NewClient(logger)
if err != nil {
    logger.Error("Failed to initialize Vault client", "error", err)
    // Fallback to environment variables for local development
    logger.Warn("Using environment variables for secrets (development only)")
} else {
    // Get database password from Vault
    dbPassword, err := vaultClient.GetSecretField(ctx, "webapp/database", "password")
    if err != nil {
        log.Fatal("Failed to get database password from Vault:", err)
    }
    dbConfig.Password = dbPassword

    // Start token renewal goroutine
    go func() {
        ticker := time.NewTicker(12 * time.Hour)
        defer ticker.Stop()
        for range ticker.C {
            if err := vaultClient.RenewToken(context.Background()); err != nil {
                logger.Error("Token renewal failed", "error", err)
            }
        }
    }()
}
```

#### 3.2.5. Vault CSI Driver (Alternative Integration)

**File:** `infra-gitops/apps/webapp/base/vault-csi.yaml`

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: webapp-vault-secrets
  namespace: default
spec:
  provider: vault
  parameters:
    vaultAddress: "http://vault.vault.svc.cluster.local:8200"
    roleName: "webapp"
    objects: |
      - objectName: "db-password"
        secretPath: "secret/data/webapp/database"
        secretKey: "password"
      - objectName: "api-key"
        secretPath: "secret/data/webapp/api"
        secretKey: "key"
  secretObjects:
  - secretName: webapp-vault-secrets
    type: Opaque
    data:
    - objectName: db-password
      key: DB_PASSWORD
    - objectName: api-key
      key: API_KEY
```

**Deployment with CSI:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-backend
spec:
  template:
    spec:
      serviceAccountName: webapp
      containers:
      - name: backend
        image: ghcr.io/soft-yt/webapp-backend:latest
        envFrom:
        - secretRef:
            name: webapp-vault-secrets
        volumeMounts:
        - name: secrets-store
          mountPath: "/mnt/secrets-store"
          readOnly: true
      volumes:
      - name: secrets-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "webapp-vault-secrets"
```

---

## 4. Observability Stack Specification

### 4.1. Structured Logging

#### 4.1.1. Logger Implementation (zerolog)

**File:** `backend/internal/logger/logger.go`

```go
package logger

import (
    "context"
    "os"
    "time"

    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
)

type contextKey string

const (
    RequestIDKey contextKey = "request_id"
    TraceIDKey   contextKey = "trace_id"
    UserIDKey    contextKey = "user_id"
)

// InitLogger initializes structured logger
func InitLogger(environment string) zerolog.Logger {
    zerolog.TimeFieldFormat = time.RFC3339Nano

    var logger zerolog.Logger

    if environment == "development" {
        // Pretty print for development
        logger = zerolog.New(zerolog.ConsoleWriter{
            Out:        os.Stdout,
            TimeFormat: "15:04:05.000",
        }).With().Timestamp().Caller().Logger()
    } else {
        // JSON for production
        logger = zerolog.New(os.Stdout).With().Timestamp().Caller().Logger()
    }

    // Set global log level
    switch environment {
    case "development":
        zerolog.SetGlobalLevel(zerolog.DebugLevel)
    case "staging":
        zerolog.SetGlobalLevel(zerolog.InfoLevel)
    case "production":
        zerolog.SetGlobalLevel(zerolog.WarnLevel)
    default:
        zerolog.SetGlobalLevel(zerolog.InfoLevel)
    }

    log.Logger = logger
    return logger
}

// WithRequestID adds request ID to context
func WithRequestID(ctx context.Context, requestID string) context.Context {
    return context.WithValue(ctx, RequestIDKey, requestID)
}

// WithTraceID adds trace ID to context
func WithTraceID(ctx context.Context, traceID string) context.Context {
    return context.WithValue(ctx, TraceIDKey, traceID)
}

// WithUserID adds user ID to context
func WithUserID(ctx context.Context, userID string) context.Context {
    return context.WithValue(ctx, UserIDKey, userID)
}

// FromContext creates logger with context fields
func FromContext(ctx context.Context, base zerolog.Logger) zerolog.Logger {
    logger := base.With()

    if requestID, ok := ctx.Value(RequestIDKey).(string); ok && requestID != "" {
        logger = logger.Str("request_id", requestID)
    }

    if traceID, ok := ctx.Value(TraceIDKey).(string); ok && traceID != "" {
        logger = logger.Str("trace_id", traceID)
    }

    if userID, ok := ctx.Value(UserIDKey).(string); ok && userID != "" {
        logger = logger.Str("user_id", userID)
    }

    return logger.Logger()
}
```

#### 4.1.2. Logging Middleware

**File:** `backend/internal/http/middleware/logging.go`

```go
package middleware

import (
    "net/http"
    "time"

    "github.com/google/uuid"
    "github.com/rs/zerolog"
    "github.com/soft-yt/app-base-go-react/internal/logger"
)

// RequestLogger middleware logs HTTP requests
func RequestLogger(log zerolog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            start := time.Now()

            // Generate request ID
            requestID := r.Header.Get("X-Request-ID")
            if requestID == "" {
                requestID = uuid.New().String()
            }

            // Add to response headers
            w.Header().Set("X-Request-ID", requestID)

            // Add to context
            ctx := logger.WithRequestID(r.Context(), requestID)
            r = r.WithContext(ctx)

            // Wrap response writer to capture status
            wrapped := &responseWriter{
                ResponseWriter: w,
                statusCode:     http.StatusOK,
            }

            // Log request
            reqLogger := logger.FromContext(ctx, log)
            reqLogger.Info().
                Str("method", r.Method).
                Str("path", r.URL.Path).
                Str("remote_addr", r.RemoteAddr).
                Str("user_agent", r.UserAgent()).
                Msg("Request started")

            // Call next handler
            next.ServeHTTP(wrapped, r)

            // Log response
            duration := time.Since(start)
            reqLogger.Info().
                Int("status", wrapped.statusCode).
                Dur("duration_ms", duration).
                Int64("bytes_written", wrapped.bytesWritten).
                Msg("Request completed")
        })
    }
}

type responseWriter struct {
    http.ResponseWriter
    statusCode    int
    bytesWritten  int64
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

func (rw *responseWriter) Write(b []byte) (int, error) {
    n, err := rw.ResponseWriter.Write(b)
    rw.bytesWritten += int64(n)
    return n, err
}
```

**Usage Example:**
```go
// In service layer
logger := logger.FromContext(ctx, s.logger)
logger.Info().
    Str("item_id", id).
    Msg("Creating new item")

// With structured errors
logger.Error().
    Err(err).
    Str("item_id", id).
    Str("operation", "create").
    Msg("Failed to create item")
```

---

### 4.2. Prometheus Metrics

#### 4.2.1. Metrics Instrumentation (Backend)

**File:** `backend/internal/metrics/metrics.go`

```go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // HTTP metrics
    HTTPRequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    HTTPRequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path", "status"},
    )

    HTTPRequestSizeBytes = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_size_bytes",
            Help:    "HTTP request size in bytes",
            Buckets: prometheus.ExponentialBuckets(100, 10, 7),
        },
        []string{"method", "path"},
    )

    HTTPResponseSizeBytes = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_response_size_bytes",
            Help:    "HTTP response size in bytes",
            Buckets: prometheus.ExponentialBuckets(100, 10, 7),
        },
        []string{"method", "path", "status"},
    )

    // Business metrics
    ItemsCreatedTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "items_created_total",
            Help: "Total number of items created",
        },
    )

    ItemsDeletedTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "items_deleted_total",
            Help: "Total number of items deleted",
        },
    )

    ActiveItemsGauge = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "active_items",
            Help: "Current number of active items",
        },
    )

    // Database metrics
    DBConnectionsOpen = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "db_connections_open",
            Help: "Number of open database connections",
        },
    )

    DBConnectionsInUse = promauto.NewGauge(
        prometheus.GaugeOpts{
            Name: "db_connections_in_use",
            Help: "Number of database connections in use",
        },
    )

    DBQueriesTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "db_queries_total",
            Help: "Total number of database queries",
        },
        []string{"operation", "status"},
    )

    DBQueryDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "db_query_duration_seconds",
            Help:    "Database query duration in seconds",
            Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0},
        },
        []string{"operation"},
    )

    // Cache metrics (for future use)
    CacheHitsTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "cache_hits_total",
            Help: "Total number of cache hits",
        },
    )

    CacheMissesTotal = promauto.NewCounter(
        prometheus.CounterOpts{
            Name: "cache_misses_total",
            Help: "Total number of cache misses",
        },
    )
)

// UpdateDBMetrics updates database connection pool metrics
func UpdateDBMetrics(stats any) {
    // Type assertion for sql.DBStats
    if dbStats, ok := stats.(interface {
        OpenConnections() int
        InUse() int
    }); ok {
        DBConnectionsOpen.Set(float64(dbStats.OpenConnections()))
        DBConnectionsInUse.Set(float64(dbStats.InUse()))
    }
}
```

#### 4.2.2. Metrics Middleware

**File:** `backend/internal/http/middleware/metrics.go`

```go
package middleware

import (
    "net/http"
    "strconv"
    "time"

    "github.com/soft-yt/app-base-go-react/internal/metrics"
)

// Metrics middleware records HTTP metrics
func Metrics(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        // Wrap response writer
        wrapped := &metricsResponseWriter{
            ResponseWriter: w,
            statusCode:     http.StatusOK,
        }

        // Track request size
        if r.ContentLength > 0 {
            metrics.HTTPRequestSizeBytes.WithLabelValues(
                r.Method,
                r.URL.Path,
            ).Observe(float64(r.ContentLength))
        }

        // Call next handler
        next.ServeHTTP(wrapped, r)

        // Record metrics
        duration := time.Since(start).Seconds()
        status := strconv.Itoa(wrapped.statusCode)

        metrics.HTTPRequestsTotal.WithLabelValues(
            r.Method,
            r.URL.Path,
            status,
        ).Inc()

        metrics.HTTPRequestDuration.WithLabelValues(
            r.Method,
            r.URL.Path,
            status,
        ).Observe(duration)

        metrics.HTTPResponseSizeBytes.WithLabelValues(
            r.Method,
            r.URL.Path,
            status,
        ).Observe(float64(wrapped.bytesWritten))
    })
}

type metricsResponseWriter struct {
    http.ResponseWriter
    statusCode   int
    bytesWritten int
}

func (m *metricsResponseWriter) WriteHeader(code int) {
    m.statusCode = code
    m.ResponseWriter.WriteHeader(code)
}

func (m *metricsResponseWriter) Write(b []byte) (int, error) {
    n, err := m.ResponseWriter.Write(b)
    m.bytesWritten += n
    return n, err
}
```

#### 4.2.3. Metrics Endpoint

**File:** `backend/cmd/api/main.go` (additions)

```go
import (
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

func setupRoutes(r chi.Router, handlers *handlers.ItemHandler, logger zerolog.Logger) {
    // Metrics endpoint
    r.Handle("/metrics", promhttp.Handler())

    // Health checks
    r.Get("/health", healthCheckHandler)
    r.Get("/ready", readinessCheckHandler)

    // API routes with middleware
    r.Route("/api/v1", func(r chi.Router) {
        r.Use(middleware.RequestLogger(logger))
        r.Use(middleware.Metrics)
        r.Use(middleware.RateLimit)

        // Item routes
        r.Route("/items", func(r chi.Router) {
            r.Get("/", handlers.ListItems)
            r.Post("/", handlers.CreateItem)
            r.Get("/{id}", handlers.GetItem)
            r.Put("/{id}", handlers.UpdateItem)
            r.Patch("/{id}", handlers.PatchItem)
            r.Delete("/{id}", handlers.DeleteItem)
        })
    })
}

// Update DB metrics periodically
go func() {
    ticker := time.NewTicker(15 * time.Second)
    defer ticker.Stop()
    for range ticker.C {
        stats := db.Stats()
        metrics.UpdateDBMetrics(stats)
    }
}()
```

#### 4.2.4. Prometheus Deployment

**File:** `infra-gitops/apps/prometheus/base/deployment.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: '${CLUSTER_NAME}'
        environment: '${ENVIRONMENT}'

    scrape_configs:
      # Kubernetes API server
      - job_name: 'kubernetes-apiservers'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      # Kubernetes nodes
      - job_name: 'kubernetes-nodes'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)

      # Application pods with /metrics endpoint
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name

      # Service endpoints
      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--storage.tsdb.retention.time=30d'
        - '--web.enable-lifecycle'
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-data
```

#### 4.2.5. Application Annotations for Scraping

**File:** `infra-gitops/apps/webapp/base/deployment.yaml` (annotations)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-backend
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: backend
        image: ghcr.io/soft-yt/webapp-backend:latest
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
```

---

### 4.3. Grafana Dashboards

#### 4.3.1. Grafana Deployment

**File:** `infra-gitops/apps/grafana/base/deployment.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus.monitoring.svc.cluster.local:9090
      isDefault: true
      editable: true

    - name: Loki
      type: loki
      access: proxy
      url: http://loki.monitoring.svc.cluster.local:3100
      editable: true

    - name: Tempo
      type: tempo
      access: proxy
      url: http://tempo.monitoring.svc.cluster.local:3200
      editable: true

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.2.2
        ports:
        - containerPort: 3000
          name: http
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secrets
              key: admin-password
        - name: GF_INSTALL_PLUGINS
          value: "grafana-piechart-panel"
        volumeMounts:
        - name: datasources
          mountPath: /etc/grafana/provisioning/datasources
        - name: dashboards-config
          mountPath: /etc/grafana/provisioning/dashboards
        - name: dashboards
          mountPath: /var/lib/grafana/dashboards
        - name: storage
          mountPath: /var/lib/grafana
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: datasources
        configMap:
          name: grafana-datasources
      - name: dashboards-config
        configMap:
          name: grafana-dashboards-config
      - name: dashboards
        configMap:
          name: grafana-dashboards
      - name: storage
        persistentVolumeClaim:
          claimName: grafana-storage
```

#### 4.3.2. Application Dashboard JSON

**File:** `infra-gitops/docs/assets/grafana/webapp-dashboard.json`

```json
{
  "dashboard": {
    "title": "WebApp Overview",
    "tags": ["webapp", "backend"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"webapp-backend\"}[5m])) by (method, path)",
            "legendFormat": "{{method}} {{path}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"webapp-backend\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"webapp-backend\"}[5m]))",
            "legendFormat": "Error Rate %"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Response Time (p50, p95, p99)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{job=\"webapp-backend\"}[5m])) by (le))",
            "legendFormat": "p50"
          },
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"webapp-backend\"}[5m])) by (le))",
            "legendFormat": "p95"
          },
          {
            "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job=\"webapp-backend\"}[5m])) by (le))",
            "legendFormat": "p99"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "db_connections_open{job=\"webapp-backend\"}",
            "legendFormat": "Open"
          },
          {
            "expr": "db_connections_in_use{job=\"webapp-backend\"}",
            "legendFormat": "In Use"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      },
      {
        "id": 5,
        "title": "Items Created",
        "type": "stat",
        "targets": [
          {
            "expr": "items_created_total{job=\"webapp-backend\"}",
            "legendFormat": "Total"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 16}
      },
      {
        "id": 6,
        "title": "Active Items",
        "type": "stat",
        "targets": [
          {
            "expr": "active_items{job=\"webapp-backend\"}",
            "legendFormat": "Count"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 6, "y": 16}
      }
    ],
    "refresh": "10s",
    "time": {
      "from": "now-1h",
      "to": "now"
    }
  }
}
```

---

### 4.4. Loki (Centralized Logging)

#### 4.4.1. Loki Deployment

**File:** `infra-gitops/apps/loki/base/statefulset.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: monitoring
data:
  loki.yaml: |
    auth_enabled: false

    server:
      http_listen_port: 3100
      grpc_listen_port: 9096

    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory

    schema_config:
      configs:
        - from: 2023-01-01
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h

    limits_config:
      enforce_metric_name: false
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20

    chunk_store_config:
      max_look_back_period: 720h

    table_manager:
      retention_deletes_enabled: true
      retention_period: 720h

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: loki
  namespace: monitoring
spec:
  serviceName: loki
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
      - name: loki
        image: grafana/loki:2.9.3
        args:
        - -config.file=/etc/loki/loki.yaml
        ports:
        - containerPort: 3100
          name: http
        - containerPort: 9096
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: data
          mountPath: /loki
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
      volumes:
      - name: config
        configMap:
          name: loki-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 50Gi
```

#### 4.4.2. Promtail (Log Shipper)

**File:** `infra-gitops/apps/loki/base/promtail-daemonset.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push

    scrape_configs:
      # Kubernetes pod logs
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: __host__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - action: replace
            replacement: $1
            separator: /
            source_labels:
              - __meta_kubernetes_namespace
              - __meta_kubernetes_pod_name
            target_label: job
          - action: replace
            source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - action: replace
            source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - action: replace
            source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
          - replacement: /var/log/pods/*$1/*.log
            separator: /
            source_labels:
              - __meta_kubernetes_pod_uid
              - __meta_kubernetes_pod_container_name
            target_label: __path__

        # Extract JSON logs
        pipeline_stages:
          - json:
              expressions:
                level: level
                message: message
                timestamp: timestamp
                request_id: request_id
                trace_id: trace_id
          - labels:
              level:
              request_id:
              trace_id:

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
      - name: promtail
        image: grafana/promtail:2.9.3
        args:
        - -config.file=/etc/promtail/promtail.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

---

### 4.5. Tempo (Distributed Tracing)

#### 4.5.1. OpenTelemetry SDK Integration (Backend)

**File:** `backend/internal/tracing/tracing.go`

```go
package tracing

import (
    "context"
    "fmt"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.21.0"
    "go.opentelemetry.io/otel/trace"
)

// InitTracer initializes OpenTelemetry tracer
func InitTracer(serviceName, environment, tempoEndpoint string) (func(context.Context) error, error) {
    // Create OTLP HTTP exporter
    exporter, err := otlptracehttp.New(
        context.Background(),
        otlptracehttp.WithEndpoint(tempoEndpoint),
        otlptracehttp.WithInsecure(), // Use TLS in production
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create exporter: %w", err)
    }

    // Create resource with service information
    res, err := resource.New(
        context.Background(),
        resource.WithAttributes(
            semconv.ServiceName(serviceName),
            semconv.ServiceVersion("1.0.0"),
            attribute.String("environment", environment),
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to create resource: %w", err)
    }

    // Create trace provider
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.AlwaysSample()),
    )

    // Register as global tracer provider
    otel.SetTracerProvider(tp)

    // Set global propagator to tracecontext (W3C Trace Context)
    otel.SetTextMapPropagator(propagation.TraceContext{})

    // Return shutdown function
    return tp.Shutdown, nil
}

// GetTracer returns a tracer for the given name
func GetTracer(name string) trace.Tracer {
    return otel.Tracer(name)
}
```

#### 4.5.2. Tracing Middleware

**File:** `backend/internal/http/middleware/tracing.go`

```go
package middleware

import (
    "net/http"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/trace"
)

// Tracing middleware adds distributed tracing
func Tracing(serviceName string) func(http.Handler) http.Handler {
    tracer := otel.Tracer(serviceName)
    propagator := otel.GetTextMapPropagator()

    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Extract trace context from headers
            ctx := propagator.Extract(r.Context(), propagation.HeaderCarrier(r.Header))

            // Start span
            ctx, span := tracer.Start(ctx, r.Method+" "+r.URL.Path,
                trace.WithAttributes(
                    attribute.String("http.method", r.Method),
                    attribute.String("http.url", r.URL.String()),
                    attribute.String("http.scheme", r.URL.Scheme),
                    attribute.String("http.host", r.Host),
                    attribute.String("http.user_agent", r.UserAgent()),
                    attribute.String("http.remote_addr", r.RemoteAddr),
                ),
            )
            defer span.End()

            // Add trace ID to response headers
            w.Header().Set("X-Trace-ID", span.SpanContext().TraceID().String())

            // Add to context
            r = r.WithContext(ctx)

            // Wrap response writer to capture status
            wrapped := &tracingResponseWriter{
                ResponseWriter: w,
                statusCode:     http.StatusOK,
            }

            // Call next handler
            next.ServeHTTP(wrapped, r)

            // Add response attributes
            span.SetAttributes(
                attribute.Int("http.status_code", wrapped.statusCode),
                attribute.Int64("http.response_size", wrapped.bytesWritten),
            )

            // Set span status based on HTTP status
            if wrapped.statusCode >= 400 {
                span.SetAttributes(attribute.Bool("error", true))
            }
        })
    }
}

type tracingResponseWriter struct {
    http.ResponseWriter
    statusCode   int
    bytesWritten int64
}

func (t *tracingResponseWriter) WriteHeader(code int) {
    t.statusCode = code
    t.ResponseWriter.WriteHeader(code)
}

func (t *tracingResponseWriter) Write(b []byte) (int, error) {
    n, err := t.ResponseWriter.Write(b)
    t.bytesWritten += int64(n)
    return n, err
}
```

#### 4.5.3. Service Layer Tracing

**File:** `backend/internal/service/item_service_impl.go` (additions)

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/codes"
)

var tracer = otel.Tracer("item-service")

func (s *itemServiceImpl) CreateItem(ctx context.Context, input models.CreateItemInput) (*models.Item, error) {
    ctx, span := tracer.Start(ctx, "CreateItem")
    defer span.End()

    span.SetAttributes(
        attribute.String("item.name", input.Name),
        attribute.Int("item.tags_count", len(input.Tags)),
    )

    // Validate input
    if err := input.Validate(); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, "validation failed")
        return nil, fmt.Errorf("validation failed: %w", err)
    }

    // Create item
    item := &models.Item{
        ID:          uuid.New().String(),
        Name:        input.Name,
        Description: input.Description,
        Tags:        input.Tags,
        Metadata:    input.Metadata,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }

    // Save to repository
    if err := s.repo.Create(ctx, item); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, "repository error")
        return nil, fmt.Errorf("failed to create item: %w", err)
    }

    span.SetAttributes(attribute.String("item.id", item.ID))
    span.SetStatus(codes.Ok, "item created successfully")

    return item, nil
}
```

#### 4.5.4. Tempo Deployment

**File:** `infra-gitops/apps/tempo/base/statefulset.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: tempo-config
  namespace: monitoring
data:
  tempo.yaml: |
    server:
      http_listen_port: 3200

    distributor:
      receivers:
        otlp:
          protocols:
            http:
              endpoint: 0.0.0.0:4318
            grpc:
              endpoint: 0.0.0.0:4317

    ingester:
      trace_idle_period: 10s
      max_block_bytes: 1_000_000
      max_block_duration: 5m

    compactor:
      compaction:
        block_retention: 168h

    storage:
      trace:
        backend: local
        local:
          path: /var/tempo/traces
        wal:
          path: /var/tempo/wal

    overrides:
      per_tenant_override_config: /conf/overrides.yaml

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tempo
  namespace: monitoring
spec:
  serviceName: tempo
  replicas: 1
  selector:
    matchLabels:
      app: tempo
  template:
    metadata:
      labels:
        app: tempo
    spec:
      containers:
      - name: tempo
        image: grafana/tempo:2.3.1
        args:
        - -config.file=/conf/tempo.yaml
        - -mem-ballast-size-mbs=1024
        ports:
        - containerPort: 3200
          name: http
        - containerPort: 4317
          name: otlp-grpc
        - containerPort: 4318
          name: otlp-http
        volumeMounts:
        - name: config
          mountPath: /conf
        - name: data
          mountPath: /var/tempo
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "1000m"
      volumes:
      - name: config
        configMap:
          name: tempo-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 50Gi
```

---

## 5. Security Features Specification

### 5.1. Rate Limiting

#### 5.1.1. Rate Limiter Implementation (Token Bucket)

**File:** `backend/internal/ratelimit/ratelimit.go`

```go
package ratelimit

import (
    "net"
    "net/http"
    "sync"
    "time"

    "golang.org/x/time/rate"
)

// IPRateLimiter manages rate limiters per IP address
type IPRateLimiter struct {
    limiters map[string]*rate.Limiter
    mu       sync.RWMutex
    rate     rate.Limit
    burst    int
    cleanup  time.Duration
}

// NewIPRateLimiter creates a new IP-based rate limiter
func NewIPRateLimiter(requestsPerSecond int, burst int, cleanupInterval time.Duration) *IPRateLimiter {
    limiter := &IPRateLimiter{
        limiters: make(map[string]*rate.Limiter),
        rate:     rate.Limit(requestsPerSecond),
        burst:    burst,
        cleanup:  cleanupInterval,
    }

    // Start cleanup goroutine
    go limiter.cleanupStale()

    return limiter
}

// GetLimiter returns rate limiter for IP
func (i *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
    i.mu.Lock()
    defer i.mu.Unlock()

    limiter, exists := i.limiters[ip]
    if !exists {
        limiter = rate.NewLimiter(i.rate, i.burst)
        i.limiters[ip] = limiter
    }

    return limiter
}

// Allow checks if request is allowed
func (i *IPRateLimiter) Allow(ip string) bool {
    return i.GetLimiter(ip).Allow()
}

// cleanupStale removes old limiters to prevent memory leak
func (i *IPRateLimiter) cleanupStale() {
    ticker := time.NewTicker(i.cleanup)
    defer ticker.Stop()

    for range ticker.C {
        i.mu.Lock()
        // In production, track last access time
        // For simplicity, we clear all limiters periodically
        if len(i.limiters) > 10000 {
            i.limiters = make(map[string]*rate.Limiter)
        }
        i.mu.Unlock()
    }
}

// getIP extracts IP from request
func getIP(r *http.Request) string {
    // Check X-Forwarded-For header (behind proxy/load balancer)
    forwarded := r.Header.Get("X-Forwarded-For")
    if forwarded != "" {
        // Take first IP if multiple
        ips := parseForwardedHeader(forwarded)
        if len(ips) > 0 {
            return ips[0]
        }
    }

    // Check X-Real-IP header
    realIP := r.Header.Get("X-Real-IP")
    if realIP != "" {
        return realIP
    }

    // Fall back to RemoteAddr
    ip, _, err := net.SplitHostPort(r.RemoteAddr)
    if err != nil {
        return r.RemoteAddr
    }

    return ip
}

func parseForwardedHeader(forwarded string) []string {
    var ips []string
    for _, part := range strings.Split(forwarded, ",") {
        ip := strings.TrimSpace(part)
        if ip != "" {
            ips = append(ips, ip)
        }
    }
    return ips
}
```

#### 5.1.2. Rate Limiting Middleware

**File:** `backend/internal/http/middleware/ratelimit.go`

```go
package middleware

import (
    "net/http"

    "github.com/soft-yt/app-base-go-react/internal/ratelimit"
)

var limiter = ratelimit.NewIPRateLimiter(10, 20, 5*time.Minute)

// RateLimit middleware limits requests per IP
func RateLimit(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ip := ratelimit.GetIP(r)

        if !limiter.Allow(ip) {
            http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
            return
        }

        next.ServeHTTP(w, r)
    })
}
```

#### 5.1.3. Rate Limit Configuration

**Environment Variables:**
```bash
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_SECOND=10
RATE_LIMIT_BURST=20
RATE_LIMIT_CLEANUP_INTERVAL=5m
```

**Test Cases:**
```go
// backend/internal/http/middleware/ratelimit_test.go

func TestRateLimit_AllowsWithinLimit(t *testing.T) {
    // Create test handler
    handler := RateLimit(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))

    // Make requests within limit
    for i := 0; i < 10; i++ {
        req := httptest.NewRequest("GET", "/api/items", nil)
        req.RemoteAddr = "192.168.1.1:1234"
        w := httptest.NewRecorder()

        handler.ServeHTTP(w, req)

        assert.Equal(t, http.StatusOK, w.Code)
    }
}

func TestRateLimit_BlocksExceedingLimit(t *testing.T) {
    handler := RateLimit(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
    }))

    // Exhaust rate limit (burst = 20)
    for i := 0; i < 25; i++ {
        req := httptest.NewRequest("GET", "/api/items", nil)
        req.RemoteAddr = "192.168.1.1:1234"
        w := httptest.NewRecorder()

        handler.ServeHTTP(w, req)

        if i < 20 {
            assert.Equal(t, http.StatusOK, w.Code)
        } else {
            assert.Equal(t, http.StatusTooManyRequests, w.Code)
        }
    }
}
```

---

### 5.2. Input Sanitization

#### 5.2.1. XSS Protection Middleware

**File:** `backend/internal/http/middleware/sanitize.go`

```go
package middleware

import (
    "html"
    "net/http"
    "strings"

    "github.com/microcosm-cc/bluemonday"
)

var policy = bluemonday.StrictPolicy()

// Sanitize middleware cleans user input
func Sanitize(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Sanitize query parameters
        query := r.URL.Query()
        for key, values := range query {
            for i, value := range values {
                query[key][i] = policy.Sanitize(value)
            }
        }
        r.URL.RawQuery = query.Encode()

        // Sanitize headers (specific ones)
        dangerousHeaders := []string{"X-Custom-Data", "X-User-Input"}
        for _, header := range dangerousHeaders {
            if value := r.Header.Get(header); value != "" {
                r.Header.Set(header, html.EscapeString(value))
            }
        }

        // Note: JSON body sanitization happens at model validation level

        next.ServeHTTP(w, r)
    })
}

// SanitizeString removes HTML tags and escapes dangerous characters
func SanitizeString(input string) string {
    // Remove HTML tags
    cleaned := policy.Sanitize(input)

    // Trim whitespace
    cleaned = strings.TrimSpace(cleaned)

    return cleaned
}
```

#### 5.2.2. Model Validation with Sanitization

**File:** `backend/internal/models/item.go` (additions)

```go
import (
    "github.com/soft-yt/app-base-go-react/internal/http/middleware"
)

func (i *CreateItemInput) Validate() error {
    // Sanitize inputs
    i.Name = middleware.SanitizeString(i.Name)
    i.Description = middleware.SanitizeString(i.Description)

    // Sanitize tags
    for idx, tag := range i.Tags {
        i.Tags[idx] = middleware.SanitizeString(tag)
    }

    // Validation rules
    if i.Name == "" {
        return errors.New("name is required")
    }

    if len(i.Name) > 255 {
        return errors.New("name must be 255 characters or less")
    }

    if len(i.Description) > 2000 {
        return errors.New("description must be 2000 characters or less")
    }

    if len(i.Tags) > 10 {
        return errors.New("maximum 10 tags allowed")
    }

    // Validate each tag
    for _, tag := range i.Tags {
        if len(tag) > 50 {
            return errors.New("each tag must be 50 characters or less")
        }
        if strings.ContainsAny(tag, "<>\"'&") {
            return errors.New("tags contain invalid characters")
        }
    }

    return nil
}
```

---

### 5.3. Security Testing

#### 5.3.1. OWASP Top 10 Testing Checklist

**File:** `docs/security-testing-checklist.md`

```markdown
# Security Testing Checklist (OWASP Top 10 2021)

## A01:2021 - Broken Access Control
- [ ] Test unauthorized access to admin endpoints
- [ ] Verify user can only access their own resources
- [ ] Test directory traversal attempts
- [ ] Validate JWT token expiration
- [ ] Test privilege escalation attempts

## A02:2021 - Cryptographic Failures
- [ ] Verify TLS 1.3 is enforced
- [ ] Check password storage (bcrypt/argon2)
- [ ] Validate secret encryption at rest (SOPS)
- [ ] Test for sensitive data in logs
- [ ] Verify secure random number generation

## A03:2021 - Injection
- [ ] SQL injection tests (automated with sqlmap)
- [ ] NoSQL injection tests
- [ ] Command injection tests
- [ ] LDAP injection tests
- [ ] XPath injection tests

## A04:2021 - Insecure Design
- [ ] Threat modeling completed
- [ ] Rate limiting on all endpoints
- [ ] Account lockout after failed attempts
- [ ] Secure password reset flow
- [ ] Proper session management

## A05:2021 - Security Misconfiguration
- [ ] Remove default credentials
- [ ] Disable unnecessary HTTP methods
- [ ] Security headers present (CSP, HSTS, etc.)
- [ ] Error messages don't leak info
- [ ] Latest security patches applied

## A06:2021 - Vulnerable Components
- [ ] Dependency scanning (npm audit, go mod)
- [ ] SBOM generation and review
- [ ] Container image scanning (Grype)
- [ ] Known CVE check (GitHub Dependabot)
- [ ] Regular dependency updates

## A07:2021 - Identification & Authentication
- [ ] Strong password policy enforced
- [ ] Multi-factor authentication available
- [ ] Session fixation protection
- [ ] Secure password recovery
- [ ] Account enumeration prevention

## A08:2021 - Software & Data Integrity
- [ ] Code signing (Cosign)
- [ ] Subresource Integrity (SRI) for CDN
- [ ] Verify CI/CD pipeline integrity
- [ ] Auto-update verification
- [ ] Integrity checks for uploads

## A09:2021 - Security Logging & Monitoring
- [ ] Authentication failures logged
- [ ] Access control failures logged
- [ ] Input validation failures logged
- [ ] Centralized log management (Loki)
- [ ] Alerting on suspicious activity

## A10:2021 - Server-Side Request Forgery (SSRF)
- [ ] URL validation for external requests
- [ ] Whitelist allowed domains
- [ ] Disable redirects
- [ ] Network segmentation
- [ ] Firewall egress filtering
```

#### 5.3.2. Automated Security Testing

**File:** `.github/workflows/security-scan.yml`

```yaml
name: Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run npm audit (frontend)
        working-directory: ./frontend
        run: npm audit --audit-level=moderate

      - name: Run Go vulnerability check (backend)
        working-directory: ./backend
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build backend image
        run: docker build -t webapp-backend:test -f backend/Dockerfile backend/

      - name: Scan with Grype
        uses: anchore/scan-action@v3
        with:
          image: webapp-backend:test
          fail-build: true
          severity-cutoff: high

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: webapp-backend:test
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom.spdx.json

  sast-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/owasp-top-ten
            p/golang

  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Scan for secrets
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

### 5.4. Image Signing with Cosign

#### 5.4.1. Cosign Setup

**Install Cosign:**
```bash
# GitHub Actions
- name: Install Cosign
  uses: sigstore/cosign-installer@v3

# Local development
brew install cosign  # macOS
# OR
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign
```

#### 5.4.2. CI/CD Integration

**File:** `.github/workflows/ci.yml` (additions)

```yaml
jobs:
  backend:
    # ... existing build steps ...

    - name: Install Cosign
      uses: sigstore/cosign-installer@v3

    - name: Sign container image
      env:
        COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
        COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
      run: |
        echo "$COSIGN_PRIVATE_KEY" > cosign.key
        cosign sign --key cosign.key \
          ghcr.io/${{ github.repository_owner }}/webapp-backend:${{ env.IMAGE_TAG }}
        rm cosign.key

    - name: Generate and attach SBOM
      run: |
        # Generate SBOM
        syft ghcr.io/${{ github.repository_owner }}/webapp-backend:${{ env.IMAGE_TAG }} \
          -o spdx-json > sbom.spdx.json

        # Attach SBOM to image
        cosign attach sbom --sbom sbom.spdx.json \
          ghcr.io/${{ github.repository_owner }}/webapp-backend:${{ env.IMAGE_TAG }}

        # Sign SBOM
        echo "$COSIGN_PRIVATE_KEY" > cosign.key
        cosign sign --key cosign.key \
          $(cosign triangulate ghcr.io/${{ github.repository_owner }}/webapp-backend:${{ env.IMAGE_TAG }} --type sbom)
        rm cosign.key
```

#### 5.4.3. Verification in Kubernetes

**Argo CD Policy:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
  namespace: argocd
data:
  registries.conf: |
    registries:
    - name: GHCR
      prefix: ghcr.io
      api_url: https://ghcr.io
      credentials: secret:argocd/ghcr-creds
      # Verify Cosign signatures
      cosign:
        enabled: true
        public_key: |
          -----BEGIN PUBLIC KEY-----
          MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
          -----END PUBLIC KEY-----
```

**Manual Verification:**
```bash
# Verify signature
cosign verify --key cosign.pub \
  ghcr.io/soft-yt/webapp-backend:v1.0.0

# Verify SBOM
cosign verify --key cosign.pub \
  $(cosign triangulate ghcr.io/soft-yt/webapp-backend:v1.0.0 --type sbom)

# Download and inspect SBOM
cosign download sbom ghcr.io/soft-yt/webapp-backend:v1.0.0 | jq .
```

---

## 6. Ingress Controller Specification

### 6.1. Ingress Controller Selection

**Decision Matrix:**

| Feature | Istio Gateway | Traefik |
|---------|---------------|---------|
| Complexity | High | Medium |
| Learning Curve | Steep | Moderate |
| Service Mesh | Yes | No |
| Traffic Management | Advanced | Basic |
| Observability | Built-in | Via plugins |
| TLS Management | Complex | Simple |
| Resource Usage | High | Low |
| Multi-cluster | Native | Requires setup |

**Recommendation:** **Traefik** for Phase 2
- Simpler to set up and maintain
- Lower resource footprint
- Excellent TLS integration with cert-manager
- Sufficient for current requirements
- Can migrate to Istio in Phase 4 if needed

---

### 6.2. Traefik Deployment

#### 6.2.1. Traefik Installation (Helm)

**File:** `infra-gitops/apps/traefik/base/values.yaml`

```yaml
# Traefik Helm values
deployment:
  replicas: 2

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

ports:
  web:
    port: 80
    exposedPort: 80
    redirectTo: websecure
  websecure:
    port: 443
    exposedPort: 443
    tls:
      enabled: true
      certResolver: letsencrypt

ingressRoute:
  dashboard:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: traefik

providers:
  kubernetesCRD:
    enabled: true
  kubernetesIngress:
    enabled: true
    publishedService:
      enabled: true

certResolvers:
  letsencrypt:
    acme:
      email: admin@soft-yt.com
      storage: /data/acme.json
      tlsChallenge: true

logs:
  general:
    level: INFO
  access:
    enabled: true
    format: json

metrics:
  prometheus:
    enabled: true
    addServicesLabels: true
    addEntryPointsLabels: true

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

#### 6.2.2. Application Ingress (IngressRoute)

**File:** `infra-gitops/apps/webapp/overlays/dev/ingress.yaml`

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: webapp-ingress
  namespace: default
spec:
  entryPoints:
    - websecure
  routes:
    # Backend API
    - match: Host(`api-dev.soft-yt.com`) && PathPrefix(`/api`)
      kind: Rule
      services:
        - name: webapp-backend
          port: 8080
      middlewares:
        - name: rate-limit
        - name: compression
        - name: headers

    # Frontend
    - match: Host(`dev.soft-yt.com`)
      kind: Rule
      services:
        - name: webapp-frontend
          port: 3000
      middlewares:
        - name: compression
        - name: headers

  tls:
    certResolver: letsencrypt
    domains:
      - main: soft-yt.com
        sans:
          - "*.soft-yt.com"

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: default
spec:
  rateLimit:
    average: 100
    burst: 200

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: compression
  namespace: default
spec:
  compress: {}

---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: headers
  namespace: default
spec:
  headers:
    customResponseHeaders:
      X-Frame-Options: "SAMEORIGIN"
      X-Content-Type-Options: "nosniff"
      X-XSS-Protection: "1; mode=block"
      Referrer-Policy: "strict-origin-when-cross-origin"
      Permissions-Policy: "geolocation=(), microphone=(), camera=()"
    contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
    stsSeconds: 31536000
    stsIncludeSubdomains: true
    stsPreload: true
```

---

### 6.3. cert-manager Integration

#### 6.3.1. cert-manager Installation

**File:** `infra-gitops/apps/cert-manager/base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cert-manager

resources:
  - https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
```

#### 6.3.2. Let's Encrypt ClusterIssuer

**File:** `infra-gitops/apps/cert-manager/base/clusterissuer.yaml`

```yaml
# Production issuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@soft-yt.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
    - http01:
        ingress:
          class: traefik
    - dns01:
        cloudflare:
          email: admin@soft-yt.com
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token

---
# Staging issuer (for testing)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@soft-yt.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: traefik
```

#### 6.3.3. Custom CA Issuer (On-Prem)

**File:** `infra-gitops/clusters/onprem-lab/cert-manager/ca-issuer.yaml`

```yaml
# Create CA secret (self-signed or corporate CA)
apiVersion: v1
kind: Secret
metadata:
  name: ca-key-pair
  namespace: cert-manager
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-certificate>
  tls.key: <base64-encoded-private-key>

---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
```

#### 6.3.4. Certificate Resource

**File:** `infra-gitops/apps/webapp/overlays/prod/certificate.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: webapp-tls
  namespace: default
spec:
  secretName: webapp-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - soft-yt.com
    - www.soft-yt.com
    - api.soft-yt.com
  privateKey:
    algorithm: RSA
    size: 4096
  duration: 2160h  # 90 days
  renewBefore: 720h  # 30 days before expiry
```

---

### 6.4. ExternalDNS Configuration

#### 6.4.1. ExternalDNS Deployment

**File:** `infra-gitops/apps/external-dns/base/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.k8s.io/external-dns/external-dns:v0.14.0
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=soft-yt.com
        - --provider=cloudflare
        - --cloudflare-proxied
        - --txt-owner-id=k8s-cluster-id
        - --txt-prefix=_external-dns.
        - --policy=sync  # or 'upsert-only'
        - --registry=txt
        - --interval=1m
        env:
        - name: CF_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-api-token
              key: token
        resources:
          requests:
            memory: "50Mi"
            cpu: "10m"
          limits:
            memory: "100Mi"
            cpu: "50m"
```

#### 6.4.2. Multi-Provider Configuration (Overlay)

**YC Cloud DNS:**
```yaml
# clusters/yc-dev/external-dns/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
spec:
  template:
    spec:
      containers:
      - name: external-dns
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=dev.soft-yt.com
        - --provider=yandex
        - --yandex-folder-id=$(YC_FOLDER_ID)
        - --txt-owner-id=yc-k8s-dev
        env:
        - name: YC_FOLDER_ID
          value: "b1gxxxxxxxxxxxxxx"
        - name: YC_SERVICE_ACCOUNT_KEY_FILE
          value: "/etc/secrets/sa-key.json"
```

---

## 7. Implementation Roadmap

### 7.1. Week 2, Days 1-2: Secrets Management

**Tasks:**
1. Install and configure SOPS with age
2. Create encryption keys per environment
3. Encrypt existing secrets (database passwords, API keys)
4. Update CI/CD to handle encrypted secrets
5. Deploy Vault to dev cluster
6. Configure Kubernetes auth
7. Test Vault integration with sample application

**Deliverables:**
- SOPS configured in `infra-gitops`
- All sensitive data encrypted
- Vault running in `monitoring` namespace
- Key rotation procedure documented

**Test Cases:**
- TS-SECRETS-001: Encrypt and decrypt secret with SOPS
- TS-SECRETS-002: Rotate SOPS key successfully
- TS-SECRETS-003: Vault Kubernetes auth succeeds
- TS-SECRETS-004: Application retrieves secret from Vault
- TS-SECRETS-005: Token renewal works correctly

---

### 7.2. Week 2, Days 3-4: Observability Stack

**Tasks:**
1. Deploy Prometheus with application scraping
2. Deploy Grafana with datasources
3. Create application dashboards
4. Deploy Loki + Promtail
5. Integrate zerolog structured logging
6. Deploy Tempo
7. Add OpenTelemetry instrumentation
8. Add metrics middleware to backend
9. Create logging and tracing middleware

**Deliverables:**
- Prometheus scraping `/metrics` endpoint
- Grafana dashboards for webapp
- Loki collecting logs from all pods
- Tempo receiving traces
- Backend instrumented with OpenTelemetry

**Test Cases:**
- TS-OBS-001: Prometheus scrapes metrics successfully
- TS-OBS-002: Grafana dashboard displays live data
- TS-OBS-003: Logs appear in Loki within 30 seconds
- TS-OBS-004: Traces visible in Tempo
- TS-OBS-005: Correlation between logs and traces works
- TS-OBS-006: Metrics recorded for all HTTP requests
- TS-OBS-007: Database metrics updated every 15 seconds

---

### 7.3. Week 2, Day 5: Security Features

**Tasks:**
1. Implement rate limiting middleware
2. Add input sanitization
3. Add security headers middleware
4. Set up security scanning in CI/CD
5. Configure Cosign for image signing
6. Generate and attach SBOMs
7. Run OWASP security tests

**Deliverables:**
- Rate limiting active on all endpoints
- Input sanitization middleware
- Security headers on all responses
- Images signed with Cosign
- SBOM generated for each image
- Security scan passing in CI

**Test Cases:**
- TS-SEC-001: Rate limit blocks after threshold
- TS-SEC-002: XSS attempts sanitized
- TS-SEC-003: Security headers present
- TS-SEC-004: Image signature verifies successfully
- TS-SEC-005: SBOM contains all dependencies
- TS-SEC-006: SQL injection blocked
- TS-SEC-007: OWASP Top 10 tests pass

---

### 7.4. Week 3, Days 1-2: Ingress Controller

**Tasks:**
1. Install Traefik via Helm
2. Configure TLS with cert-manager
3. Deploy Let's Encrypt ClusterIssuer
4. Create IngressRoute for webapp
5. Set up ExternalDNS
6. Configure custom CA for on-prem
7. Test multi-environment ingress

**Deliverables:**
- Traefik running in all clusters
- TLS certificates automatically provisioned
- DNS records automatically managed
- Application accessible via HTTPS

**Test Cases:**
- TS-ING-001: HTTP redirects to HTTPS
- TS-ING-002: TLS certificate valid and trusted
- TS-ING-003: DNS record created automatically
- TS-ING-004: Rate limiting works at ingress level
- TS-ING-005: Custom headers applied
- TS-ING-006: Certificate auto-renewal works

---

## 8. Testing Strategy

### 8.1. Unit Tests

**Secrets Management:**
```bash
# Mock Vault client tests
go test -v ./internal/vault/... -cover
```

**Observability:**
```bash
# Metrics instrumentation tests
go test -v ./internal/metrics/... -cover

# Logger tests
go test -v ./internal/logger/... -cover

# Tracing tests
go test -v ./internal/tracing/... -cover
```

**Security:**
```bash
# Rate limiter tests
go test -v ./internal/ratelimit/... -cover

# Sanitization tests
go test -v ./internal/http/middleware/sanitize_test.go -cover
```

**Target:** 85%+ coverage for all new code

---

### 8.2. Integration Tests

**Observability Integration:**
```go
// test/integration/observability_test.go

func TestObservability_MetricsExposed(t *testing.T) {
    // Start application
    app := startTestApp(t)
    defer app.Shutdown()

    // Make request
    resp, err := http.Get("http://localhost:8080/api/items")
    require.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    // Check metrics endpoint
    metricsResp, err := http.Get("http://localhost:8080/metrics")
    require.NoError(t, err)

    body, _ := io.ReadAll(metricsResp.Body)
    metricsData := string(body)

    // Verify metrics present
    assert.Contains(t, metricsData, "http_requests_total")
    assert.Contains(t, metricsData, "http_request_duration_seconds")
}

func TestObservability_LogsStructured(t *testing.T) {
    // Capture logs
    var logBuffer bytes.Buffer
    logger := zerolog.New(&logBuffer)

    // Make request with logger
    ctx := context.Background()
    ctx = logger.WithContext(ctx)
    ctx = logger.WithRequestID(ctx, "test-request-id")

    // Trigger log
    logger.FromContext(ctx).Info().Msg("Test message")

    // Parse JSON log
    var logEntry map[string]interface{}
    err := json.Unmarshal(logBuffer.Bytes(), &logEntry)
    require.NoError(t, err)

    // Verify structure
    assert.Equal(t, "Test message", logEntry["message"])
    assert.Equal(t, "test-request-id", logEntry["request_id"])
    assert.NotEmpty(t, logEntry["timestamp"])
}
```

**Security Integration:**
```go
func TestRateLimit_Integration(t *testing.T) {
    app := startTestApp(t)
    defer app.Shutdown()

    client := &http.Client{}
    successCount := 0
    rateLimitCount := 0

    // Make 100 requests rapidly
    for i := 0; i < 100; i++ {
        req, _ := http.NewRequest("GET", "http://localhost:8080/api/items", nil)
        req.Header.Set("X-Forwarded-For", "192.168.1.1")

        resp, err := client.Do(req)
        require.NoError(t, err)

        if resp.StatusCode == http.StatusOK {
            successCount++
        } else if resp.StatusCode == http.StatusTooManyRequests {
            rateLimitCount++
        }
    }

    // Verify rate limiting kicked in
    assert.Greater(t, rateLimitCount, 0)
    assert.Less(t, successCount, 100)
}
```

---

### 8.3. End-to-End Tests

**File:** `test/e2e/observability_e2e_test.go`

```go
func TestE2E_FullObservabilityStack(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping E2E test in short mode")
    }

    // Prerequisites: Prometheus, Grafana, Loki, Tempo running
    t.Run("Metrics flow", func(t *testing.T) {
        // 1. Make API request
        resp, err := http.Get("https://dev.soft-yt.com/api/items")
        require.NoError(t, err)
        assert.Equal(t, http.StatusOK, resp.StatusCode)

        // 2. Wait for scrape interval
        time.Sleep(20 * time.Second)

        // 3. Query Prometheus
        promResp, err := http.Get("http://prometheus:9090/api/v1/query?query=http_requests_total")
        require.NoError(t, err)

        var result PrometheusResponse
        json.NewDecoder(promResp.Body).Decode(&result)

        assert.Greater(t, len(result.Data.Result), 0)
    })

    t.Run("Logs flow", func(t *testing.T) {
        // Query Loki for recent logs
        lokiResp, err := http.Get(`http://loki:3100/loki/api/v1/query?query={app="webapp-backend"}`)
        require.NoError(t, err)

        var result LokiResponse
        json.NewDecoder(lokiResp.Body).Decode(&result)

        assert.Greater(t, len(result.Data.Result), 0)
    })

    t.Run("Traces flow", func(t *testing.T) {
        // Make request and get trace ID
        req, _ := http.NewRequest("GET", "https://dev.soft-yt.com/api/items", nil)
        resp, err := http.DefaultClient.Do(req)
        require.NoError(t, err)

        traceID := resp.Header.Get("X-Trace-ID")
        assert.NotEmpty(t, traceID)

        // Query Tempo
        time.Sleep(5 * time.Second)
        tempoResp, err := http.Get(fmt.Sprintf("http://tempo:3200/api/traces/%s", traceID))
        require.NoError(t, err)
        assert.Equal(t, http.StatusOK, tempoResp.StatusCode)
    })
}
```

---

## 9. Definition of Done

### 9.1. Secrets Management

- [ ] SOPS installed and configured with age
- [ ] Encryption keys generated for all environments
- [ ] All sensitive data encrypted in Git
- [ ] SOPS integrated into CI/CD pipeline
- [ ] Vault deployed to all clusters (3 replicas, HA)
- [ ] Kubernetes auth configured
- [ ] Application successfully retrieves secrets from Vault
- [ ] Token renewal mechanism implemented
- [ ] Key rotation procedure documented and tested
- [ ] Secret backup strategy documented

### 9.2. Observability

**Logging:**
- [ ] zerolog integrated in backend
- [ ] Structured logging with correlation IDs
- [ ] Logging middleware captures all requests
- [ ] Loki deployed and collecting logs
- [ ] Promtail running on all nodes
- [ ] Logs queryable in Grafana
- [ ] Log retention policy configured (30 days)

**Metrics:**
- [ ] Prometheus deployed to all clusters
- [ ] Backend `/metrics` endpoint implemented
- [ ] HTTP metrics recorded (requests, duration, size)
- [ ] Business metrics tracked (items created, deleted)
- [ ] Database metrics exposed
- [ ] Grafana deployed with datasources
- [ ] Application dashboards created
- [ ] Alert rules configured for critical metrics

**Tracing:**
- [ ] Tempo deployed
- [ ] OpenTelemetry SDK integrated
- [ ] Tracing middleware captures all requests
- [ ] Service layer methods traced
- [ ] Traces visible in Grafana
- [ ] Correlation between logs and traces works

### 9.3. Security

- [ ] Rate limiting middleware implemented
- [ ] Rate limit configurable per environment
- [ ] Input sanitization active on all endpoints
- [ ] Security headers middleware applied
- [ ] XSS protection tested
- [ ] SQL injection protection verified
- [ ] OWASP Top 10 checklist completed
- [ ] Automated security scanning in CI/CD
- [ ] Cosign configured for image signing
- [ ] All images signed before deployment
- [ ] SBOM generated for each image
- [ ] Vulnerability scanning passing (no high/critical CVEs)

### 9.4. Ingress & TLS

- [ ] Traefik deployed to all clusters
- [ ] cert-manager installed
- [ ] Let's Encrypt ClusterIssuer configured
- [ ] Custom CA issuer for on-prem
- [ ] TLS certificates automatically provisioned
- [ ] HTTP → HTTPS redirect working
- [ ] ExternalDNS managing DNS records
- [ ] Application accessible via custom domain
- [ ] Rate limiting at ingress level
- [ ] Security headers applied via middleware

### 9.5. Testing

- [ ] Unit tests for all new components
- [ ] Integration tests passing
- [ ] E2E tests for observability stack
- [ ] Security tests passing
- [ ] Load testing completed (rate limiting)
- [ ] Test coverage ≥ 85% for new code

### 9.6. Documentation

- [ ] Secrets management procedures documented
- [ ] Key rotation procedure documented
- [ ] Observability stack architecture documented
- [ ] Grafana dashboards exported to Git
- [ ] Security testing checklist completed
- [ ] Runbooks for common issues
- [ ] Updated README with new components

---

## 10. Acceptance Criteria

### AC-PHASE2-001: Secrets Encryption
**Given** a developer needs to add a new secret
**When** they create a YAML file with sensitive data
**Then** they can encrypt it with `sops -e`
**And** the encrypted file is committed to Git
**And** only authorized keys can decrypt it

### AC-PHASE2-002: Runtime Secret Retrieval
**Given** the application is deployed to Kubernetes
**When** it starts up
**Then** it authenticates to Vault using Kubernetes SA
**And** retrieves database password from Vault
**And** connects to PostgreSQL successfully

### AC-PHASE2-003: Metrics Collection
**Given** the application is receiving traffic
**When** requests are made to `/api/items`
**Then** HTTP metrics are recorded (count, duration)
**And** metrics are scraped by Prometheus every 15s
**And** metrics are visible in Grafana dashboard

### AC-PHASE2-004: Structured Logging
**Given** a user makes a request
**When** the request is processed
**Then** logs are emitted in JSON format
**And** each log has request_id and trace_id
**And** logs appear in Loki within 30 seconds
**And** logs are queryable by request_id

### AC-PHASE2-005: Distributed Tracing
**Given** a request flows through multiple services
**When** trace context is propagated
**Then** all spans are collected by Tempo
**And** full trace is visible in Grafana
**And** trace_id correlates with logs

### AC-PHASE2-006: Rate Limiting
**Given** a client makes excessive requests
**When** the rate limit threshold is exceeded
**Then** subsequent requests return 429 Too Many Requests
**And** legitimate traffic is unaffected
**And** rate limit resets after time window

### AC-PHASE2-007: Input Sanitization
**Given** a malicious user sends XSS payload
**When** the payload is in request body
**Then** HTML tags are stripped during validation
**And** safe data is stored in database
**And** no XSS is possible on retrieval

### AC-PHASE2-008: Image Signing
**Given** a Docker image is built in CI/CD
**When** the image is pushed to GHCR
**Then** it is signed with Cosign
**And** SBOM is generated and attached
**And** unsigned images are rejected by Argo CD

### AC-PHASE2-009: TLS Certificate
**Given** a new ingress is created
**When** cert-manager sees the annotation
**Then** a Let's Encrypt certificate is requested
**And** DNS-01 challenge is completed
**And** TLS certificate is issued within 5 minutes
**And** certificate is automatically renewed before expiry

### AC-PHASE2-010: Automatic DNS
**Given** a service is created with LoadBalancer type
**When** ExternalDNS detects the service
**Then** a DNS A record is created automatically
**And** the domain resolves to the LoadBalancer IP
**And** DNS record is deleted when service is removed

---

## 11. Dependencies and Tools

### 11.1. Go Modules (Backend)

```bash
# Observability
go get github.com/rs/zerolog
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracehttp
go get go.opentelemetry.io/otel/sdk/trace
go get github.com/prometheus/client_golang/prometheus

# Security
go get golang.org/x/time/rate
go get github.com/microcosm-cc/bluemonday

# Vault
go get github.com/hashicorp/vault/api
go get github.com/hashicorp/vault/api/auth/kubernetes
```

### 11.2. Infrastructure Tools

```bash
# Secrets
brew install sops age

# Image signing
brew install cosign

# SBOM generation
brew install syft grype

# cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Traefik (Helm)
helm repo add traefik https://traefik.github.io/charts
helm install traefik traefik/traefik -f values.yaml

# Prometheus stack (Helm)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack

# Loki stack (Helm)
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack
```

### 11.3. CI/CD Tools

```yaml
# .github/workflows dependencies
- sigstore/cosign-installer@v3
- anchore/scan-action@v3
- anchore/sbom-action@v0
- returntocorp/semgrep-action@v1
- gitleaks/gitleaks-action@v2
```

---

## 12. Risk Assessment

### 12.1. Technical Risks

**Risk:** SOPS key loss
**Impact:** High - Cannot decrypt secrets
**Mitigation:**
- Store keys in multiple secure locations (1Password, HSM)
- Maintain key rotation audit trail
- Test restore procedure quarterly
**Probability:** Low

**Risk:** Vault cluster failure
**Impact:** Medium - Applications cannot start/get secrets
**Mitigation:**
- 3-replica Vault with Raft storage
- Regular backup of Vault data
- Fallback to Kubernetes Secrets for critical services
**Probability:** Low

**Risk:** Observability stack resource consumption
**Impact:** Medium - Cluster resource pressure
**Mitigation:**
- Set resource limits on all components
- Implement log sampling in high-traffic scenarios
- Configure retention policies (30 days logs, 90 days metrics)
**Probability:** Medium

**Risk:** Rate limiting too aggressive
**Impact:** Medium - Legitimate users blocked
**Mitigation:**
- Start with conservative limits (100 req/s)
- Monitor false positives in Grafana
- Whitelist trusted IPs
- Implement adaptive rate limiting
**Probability:** Medium

**Risk:** Let's Encrypt rate limits
**Impact:** Low - Certificate issuance fails
**Mitigation:**
- Use staging environment for testing
- Implement exponential backoff
- Cache certificates properly
- Consider alternative ACME providers
**Probability:** Low

**Risk:** Cosign key compromise
**Impact:** High - Malicious images could be signed
**Mitigation:**
- Use Keyless signing with OIDC (Sigstore)
- Rotate signing keys quarterly
- Audit all signed images
- Implement policy to reject old signatures
**Probability:** Very Low

### 12.2. Operational Risks

**Risk:** Team unfamiliarity with observability stack
**Impact:** Medium - Slow incident response
**Mitigation:**
- Training sessions on Grafana/Loki/Tempo
- Create runbooks for common queries
- Regular practice with staging incidents
**Probability:** High

**Risk:** Alert fatigue
**Impact:** Medium - Important alerts missed
**Mitigation:**
- Start with minimal critical alerts only
- Iteratively refine thresholds based on data
- Implement on-call rotation
**Probability:** Medium

**Risk:** Certificate expiry unnoticed
**Impact:** High - Service outage
**Mitigation:**
- cert-manager auto-renewal (30 days before)
- Prometheus alert on certificate expiry < 7 days
- Weekly certificate health check
**Probability:** Low

### 12.3. Security Risks

**Risk:** SOPS keys in GitHub Secrets compromised
**Impact:** Critical - All secrets exposed
**Mitigation:**
- Use GitHub environment protection rules
- Require approvals for production deployments
- Rotate keys if compromise suspected
- Audit GitHub access regularly
**Probability:** Low

**Risk:** Vault unsealing requires manual intervention
**Impact:** High - Extended downtime
**Mitigation:**
- Implement auto-unseal with cloud KMS
- Document unseal procedure clearly
- Practice disaster recovery quarterly
**Probability:** Medium

---

## 13. Success Metrics

### 13.1. Quantitative Metrics

**Secrets Management:**
- ✅ 100% of sensitive data encrypted in Git
- ✅ Zero plain-text secrets in repositories
- ✅ Vault availability ≥ 99.9%
- ✅ Secret retrieval latency < 100ms (p95)

**Observability:**
- ✅ Prometheus scrape success rate ≥ 99%
- ✅ Log ingestion latency < 30 seconds (p95)
- ✅ Trace sampling rate = 100% (initially)
- ✅ Grafana dashboard load time < 2 seconds
- ✅ Zero data loss in logging pipeline

**Security:**
- ✅ Rate limiting blocks > 95% of DDoS attempts
- ✅ Zero XSS vulnerabilities in testing
- ✅ Zero high/critical CVEs in images
- ✅ 100% of images signed
- ✅ SBOM generated for 100% of images

**Ingress & TLS:**
- ✅ TLS certificate issuance time < 5 minutes
- ✅ Certificate renewal success rate = 100%
- ✅ DNS record creation time < 2 minutes
- ✅ Ingress availability ≥ 99.95%

### 13.2. Qualitative Metrics

**Developer Experience:**
- Developers can encrypt/decrypt secrets easily
- Observability dashboards provide actionable insights
- Security doesn't significantly slow development
- TLS "just works" without manual intervention

**Operational Excellence:**
- Incidents detected within 2 minutes (via alerts)
- Mean time to resolution (MTTR) reduced by 50%
- Security incidents reduced by 80%
- Zero production outages due to certificate expiry

**Security Posture:**
- OWASP Top 10 tests passing
- Regular penetration testing shows improvement
- Compliance requirements met (encryption at rest/transit)
- Audit trail for all secret access

---

## 14. Next Phase Preview

**Phase 3: Advanced GitOps & Multi-Cluster** will build on Phase 2 to add:
- Argo CD Image Updater for automatic promotions
- Progressive delivery (Argo Rollouts with canary/blue-green)
- Multi-cluster ApplicationSets with cluster generators
- Policy enforcement with OPA/Gatekeeper
- GitOps RBAC and approval workflows
- Crossplane for infrastructure provisioning

This phase depends on Phase 2 being 100% complete with all acceptance criteria met.

---

## 15. Appendices

### Appendix A: Environment Variables Reference

**Backend:**
```bash
# Observability
OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo.monitoring.svc.cluster.local:4318
ENVIRONMENT=production
LOG_LEVEL=info

# Vault
VAULT_ADDR=http://vault.vault.svc.cluster.local:8200
VAULT_ROLE=webapp

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_SECOND=10
RATE_LIMIT_BURST=20
```

### Appendix B: Grafana Dashboard Queries

**Request Rate:**
```promql
sum(rate(http_requests_total{job="webapp-backend"}[5m])) by (method, path)
```

**Error Rate:**
```promql
sum(rate(http_requests_total{job="webapp-backend",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{job="webapp-backend"}[5m])) * 100
```

**p95 Latency:**
```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{job="webapp-backend"}[5m])) by (le)
)
```

**Database Connections:**
```promql
db_connections_open{job="webapp-backend"}
db_connections_in_use{job="webapp-backend"}
```

### Appendix C: Alert Rules

**File:** `infra-gitops/apps/prometheus/base/alerts.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: monitoring
data:
  alerts.yml: |
    groups:
    - name: webapp
      interval: 30s
      rules:
      - alert: HighErrorRate
        expr: |
          (sum(rate(http_requests_total{job="webapp-backend",status=~"5.."}[5m]))
          / sum(rate(http_requests_total{job="webapp-backend"}[5m]))) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on webapp-backend"
          description: "Error rate is {{ $value | humanizePercentage }}"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket{job="webapp-backend"}[5m])) by (le)
          ) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency on webapp-backend"
          description: "p95 latency is {{ $value }}s"

      - alert: DatabaseConnectionsHigh
        expr: db_connections_in_use{job="webapp-backend"} > 20
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connection usage"
          description: "{{ $value }} connections in use"

      - alert: CertificateExpiringSoon
        expr: |
          (cert_manager_certificate_expiration_timestamp_seconds - time()) / 86400 < 7
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "TLS certificate expiring soon"
          description: "Certificate {{ $labels.name }} expires in {{ $value }} days"
```

### Appendix D: SOPS Commands Cheat Sheet

```bash
# Encrypt file
sops -e secrets.yaml > secrets.enc.yaml

# Decrypt file
sops -d secrets.enc.yaml

# Edit encrypted file in-place
sops secrets.enc.yaml

# Re-encrypt with new keys
sops updatekeys secrets.enc.yaml

# Extract specific field
sops -d --extract '["data"]["password"]' secrets.enc.yaml

# Set environment variable
export SOPS_AGE_KEY_FILE=~/.sops/keys.txt

# Encrypt with multiple keys
sops -e --age age1...,age2... secrets.yaml > secrets.enc.yaml
```

---

**Document Status:** Ready for Implementation
**Estimated Effort:** 2 weeks (10 working days)
**Target Start:** Immediately after Phase 1 completion
**Dependencies:** Phase 1 (Clean Architecture) must be 100% complete
**Version:** 1.0.0
**Last Updated:** 2025-10-24
