# Примеры референсной реализации

**Статус документа:** Draft · **Аудитория:** разработчики backend/frontend.

## 1. Обзор

Документ содержит примеры кода для референсной реализации компонентов платформы `soft-yt`. Все примеры следуют best practices и должны использоваться как основа для создания новых сервисов.

---

## 2. Backend (Go) - Референсная реализация

### 2.1. Структура проекта

```
backend/
├── cmd/
│   └── api/
│       └── main.go              # Точка входа
├── internal/
│   ├── config/
│   │   ├── config.go            # Конфигурация
│   │   └── config_test.go
│   ├── http/
│   │   ├── server.go            # HTTP сервер
│   │   ├── router.go            # Маршрутизация
│   │   ├── handlers/
│   │   │   ├── health.go        # Health checks
│   │   │   ├── health_test.go
│   │   │   ├── items.go         # CRUD handlers
│   │   │   └── items_test.go
│   │   └── middleware/
│   │       ├── logger.go        # Логирование
│   │       ├── recovery.go      # Panic recovery
│   │       ├── cors.go          # CORS
│   │       └── metrics.go       # Prometheus metrics
│   ├── service/
│   │   ├── item_service.go      # Бизнес-логика
│   │   └── item_service_test.go
│   ├── repository/
│   │   ├── item_repository.go   # Data access
│   │   └── item_repository_test.go
│   └── models/
│       └── item.go              # Domain models
├── test/
│   ├── integration/
│   │   └── api_test.go          # Интеграционные тесты
│   └── fixtures/
│       └── items.json           # Тестовые данные
├── go.mod
├── go.sum
├── Dockerfile
└── Makefile
```

---

### 2.2. Main Application Entry Point

**File:** `cmd/api/main.go`

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/soft-yt/app-base-go-react/internal/config"
	httpserver "github.com/soft-yt/app-base-go-react/internal/http"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Initialize HTTP server
	server := httpserver.NewServer(cfg)

	// Start server in goroutine
	go func() {
		addr := fmt.Sprintf(":%d", cfg.Port)
		log.Printf("Starting server on %s", addr)

		if err := server.Start(addr); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Server exited")
}
```

---

### 2.3. Configuration Management

**File:** `internal/config/config.go`

```go
package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds application configuration
type Config struct {
	Port         int
	LogLevel     string
	DatabaseURL  string
	Environment  string
}

// Load reads configuration from environment variables
func Load() (*Config, error) {
	cfg := &Config{
		Port:        getEnvAsInt("APP_PORT", 8080),
		LogLevel:    getEnv("APP_LOG_LEVEL", "info"),
		DatabaseURL: getEnv("DATABASE_URL", ""),
		Environment: getEnv("APP_ENV", "development"),
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	return cfg, nil
}

// Validate checks if configuration is valid
func (c *Config) Validate() error {
	if c.Port < 1 || c.Port > 65535 {
		return fmt.Errorf("invalid port: %d", c.Port)
	}

	validLogLevels := map[string]bool{
		"debug": true,
		"info":  true,
		"warn":  true,
		"error": true,
	}

	if !validLogLevels[c.LogLevel] {
		return fmt.Errorf("invalid log level: %s", c.LogLevel)
	}

	return nil
}

// IsDevelopment returns true if running in development mode
func (c *Config) IsDevelopment() bool {
	return c.Environment == "development"
}

// IsProduction returns true if running in production mode
func (c *Config) IsProduction() bool {
	return c.Environment == "production"
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	valueStr := os.Getenv(key)
	if valueStr == "" {
		return defaultValue
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}

	return value
}
```

**File:** `internal/config/config_test.go`

```go
package config

import (
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLoad_ValidConfig(t *testing.T) {
	// Arrange
	os.Setenv("APP_PORT", "9090")
	os.Setenv("APP_LOG_LEVEL", "debug")
	os.Setenv("APP_ENV", "production")
	defer os.Clearenv()

	// Act
	cfg, err := Load()

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, cfg)
	assert.Equal(t, 9090, cfg.Port)
	assert.Equal(t, "debug", cfg.LogLevel)
	assert.Equal(t, "production", cfg.Environment)
	assert.True(t, cfg.IsProduction())
	assert.False(t, cfg.IsDevelopment())
}

func TestLoad_DefaultValues(t *testing.T) {
	// Arrange
	os.Clearenv()

	// Act
	cfg, err := Load()

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 8080, cfg.Port)
	assert.Equal(t, "info", cfg.LogLevel)
	assert.Equal(t, "development", cfg.Environment)
}

func TestValidate_InvalidPort(t *testing.T) {
	// Arrange
	cfg := &Config{
		Port:     99999,
		LogLevel: "info",
	}

	// Act
	err := cfg.Validate()

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid port")
}

func TestValidate_InvalidLogLevel(t *testing.T) {
	// Arrange
	cfg := &Config{
		Port:     8080,
		LogLevel: "invalid",
	}

	// Act
	err := cfg.Validate()

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid log level")
}
```

---

### 2.4. HTTP Server

**File:** `internal/http/server.go`

```go
package http

import (
	"context"
	"net/http"
	"time"

	"github.com/soft-yt/app-base-go-react/internal/config"
)

// Server represents HTTP server
type Server struct {
	httpServer *http.Server
	config     *config.Config
}

// NewServer creates a new HTTP server
func NewServer(cfg *config.Config) *Server {
	router := NewRouter(cfg)

	return &Server{
		httpServer: &http.Server{
			Handler:           router,
			ReadTimeout:       15 * time.Second,
			ReadHeaderTimeout: 5 * time.Second,
			WriteTimeout:      15 * time.Second,
			IdleTimeout:       60 * time.Second,
		},
		config: cfg,
	}
}

// Start starts the HTTP server
func (s *Server) Start(addr string) error {
	s.httpServer.Addr = addr
	return s.httpServer.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}
```

**File:** `internal/http/router.go`

```go
package http

import (
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/soft-yt/app-base-go-react/internal/config"
	"github.com/soft-yt/app-base-go-react/internal/http/handlers"
	custommw "github.com/soft-yt/app-base-go-react/internal/http/middleware"
)

// NewRouter creates and configures the main router
func NewRouter(cfg *config.Config) *chi.Mux {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(custommw.Logger)
	r.Use(middleware.Recoverer)
	r.Use(custommw.CORS)
	r.Use(middleware.Timeout(30 * time.Second))

	// Health checks
	r.Get("/healthz", handlers.HealthCheck)
	r.Get("/readyz", handlers.ReadinessCheck)
	r.Get("/metrics", handlers.MetricsHandler)

	// API routes
	r.Route("/api/v1", func(r chi.Router) {
		// Items CRUD
		r.Route("/items", func(r chi.Router) {
			r.Get("/", handlers.ListItems)
			r.Post("/", handlers.CreateItem)

			r.Route("/{id}", func(r chi.Router) {
				r.Get("/", handlers.GetItem)
				r.Put("/", handlers.UpdateItem)
				r.Patch("/", handlers.PatchItem)
				r.Delete("/", handlers.DeleteItem)
			})
		})

		// Config endpoint
		r.Get("/config", handlers.GetConfig)
	})

	return r
}
```

---

### 2.5. Health Check Handlers

**File:** `internal/http/handlers/health.go`

```go
package handlers

import (
	"encoding/json"
	"net/http"
	"time"
)

// HealthResponse represents health check response
type HealthResponse struct {
	Status    string    `json:"status"`
	Timestamp time.Time `json:"timestamp"`
}

// ReadinessResponse represents readiness check response
type ReadinessResponse struct {
	Status    string            `json:"status"`
	Checks    map[string]string `json:"checks"`
	Timestamp time.Time         `json:"timestamp"`
}

// HealthCheck handles /healthz endpoint (liveness probe)
func HealthCheck(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// ReadinessCheck handles /readyz endpoint (readiness probe)
func ReadinessCheck(w http.ResponseWriter, r *http.Request) {
	checks := make(map[string]string)

	// Check database connectivity (if applicable)
	// dbStatus := checkDatabase()
	// checks["database"] = dbStatus

	// For now, just return ok
	checks["server"] = "ok"

	allHealthy := true
	for _, status := range checks {
		if status != "ok" {
			allHealthy = false
			break
		}
	}

	status := "ready"
	statusCode := http.StatusOK

	if !allHealthy {
		status = "not_ready"
		statusCode = http.StatusServiceUnavailable
	}

	response := ReadinessResponse{
		Status:    status,
		Checks:    checks,
		Timestamp: time.Now().UTC(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(response)
}
```

**File:** `internal/http/handlers/health_test.go`

```go
package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHealthCheck(t *testing.T) {
	// Arrange
	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()

	// Act
	HealthCheck(w, req)

	// Assert
	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

	var response HealthResponse
	err := json.NewDecoder(w.Body).Decode(&response)
	assert.NoError(t, err)
	assert.Equal(t, "healthy", response.Status)
	assert.False(t, response.Timestamp.IsZero())
}

func TestReadinessCheck_Ready(t *testing.T) {
	// Arrange
	req := httptest.NewRequest("GET", "/readyz", nil)
	w := httptest.NewRecorder()

	// Act
	ReadinessCheck(w, req)

	// Assert
	assert.Equal(t, http.StatusOK, w.Code)

	var response ReadinessResponse
	err := json.NewDecoder(w.Body).Decode(&response)
	assert.NoError(t, err)
	assert.Equal(t, "ready", response.Status)
	assert.Equal(t, "ok", response.Checks["server"])
}
```

---

### 2.6. CRUD Handlers Example

**File:** `internal/http/handlers/items.go`

```go
package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/soft-yt/app-base-go-react/internal/models"
)

// ListItems handles GET /api/v1/items
func ListItems(w http.ResponseWriter, r *http.Request) {
	// Parse query parameters
	page := getQueryInt(r, "page", 1)
	limit := getQueryInt(r, "limit", 20)

	// Validate
	if limit > 100 {
		respondWithError(w, http.StatusBadRequest, "VALIDATION_ERROR", "limit cannot exceed 100", nil)
		return
	}

	// TODO: Fetch from database
	items := []models.Item{
		{
			ID:          uuid.New().String(),
			Name:        "Sample Item",
			Description: "Sample description",
			Tags:        []string{"sample"},
		},
	}

	response := map[string]interface{}{
		"data": items,
		"pagination": map[string]int{
			"page":        page,
			"limit":       limit,
			"total":       1,
			"total_pages": 1,
		},
	}

	respondWithJSON(w, http.StatusOK, response)
}

// CreateItem handles POST /api/v1/items
func CreateItem(w http.ResponseWriter, r *http.Request) {
	var input models.CreateItemInput

	// Decode request body
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body", nil)
		return
	}

	// Validate
	if err := input.Validate(); err != nil {
		respondWithError(w, http.StatusBadRequest, "VALIDATION_ERROR", err.Error(), nil)
		return
	}

	// Create item
	item := &models.Item{
		ID:          uuid.New().String(),
		Name:        input.Name,
		Description: input.Description,
		Tags:        input.Tags,
		Metadata:    input.Metadata,
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}

	// TODO: Save to database

	respondWithJSON(w, http.StatusCreated, item)
}

// GetItem handles GET /api/v1/items/{id}
func GetItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	// Validate UUID
	if _, err := uuid.Parse(id); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_ID", "Invalid item ID format", nil)
		return
	}

	// TODO: Fetch from database
	item := &models.Item{
		ID:          id,
		Name:        "Sample Item",
		Description: "Sample description",
		Tags:        []string{"sample"},
		CreatedAt:   time.Now().UTC(),
		UpdatedAt:   time.Now().UTC(),
	}

	respondWithJSON(w, http.StatusOK, item)
}

// UpdateItem handles PUT /api/v1/items/{id}
func UpdateItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	// Validate UUID
	if _, err := uuid.Parse(id); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_ID", "Invalid item ID format", nil)
		return
	}

	var input models.UpdateItemInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body", nil)
		return
	}

	if err := input.Validate(); err != nil {
		respondWithError(w, http.StatusBadRequest, "VALIDATION_ERROR", err.Error(), nil)
		return
	}

	// TODO: Update in database
	item := &models.Item{
		ID:          id,
		Name:        input.Name,
		Description: input.Description,
		Tags:        input.Tags,
		Metadata:    input.Metadata,
		UpdatedAt:   time.Now().UTC(),
	}

	respondWithJSON(w, http.StatusOK, item)
}

// PatchItem handles PATCH /api/v1/items/{id}
func PatchItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	if _, err := uuid.Parse(id); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_ID", "Invalid item ID format", nil)
		return
	}

	var input models.PatchItemInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body", nil)
		return
	}

	// TODO: Partial update in database
	item := &models.Item{
		ID:        id,
		UpdatedAt: time.Now().UTC(),
	}

	respondWithJSON(w, http.StatusOK, item)
}

// DeleteItem handles DELETE /api/v1/items/{id}
func DeleteItem(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	if _, err := uuid.Parse(id); err != nil {
		respondWithError(w, http.StatusBadRequest, "INVALID_ID", "Invalid item ID format", nil)
		return
	}

	// TODO: Delete from database

	w.WriteHeader(http.StatusNoContent)
}

// Helper functions

func getQueryInt(r *http.Request, key string, defaultValue int) int {
	valueStr := r.URL.Query().Get(key)
	if valueStr == "" {
		return defaultValue
	}

	value, err := strconv.Atoi(valueStr)
	if err != nil {
		return defaultValue
	}

	return value
}

func respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(payload)
}

func respondWithError(w http.ResponseWriter, code int, errorCode, message string, details interface{}) {
	response := map[string]interface{}{
		"error": map[string]interface{}{
			"code":       errorCode,
			"message":    message,
			"request_id": middleware.GetReqID(r.Context()),
		},
	}

	if details != nil {
		response["error"].(map[string]interface{})["details"] = details
	}

	respondWithJSON(w, code, response)
}
```

---

### 2.7. Models

**File:** `internal/models/item.go`

```go
package models

import (
	"errors"
	"time"
)

// Item represents an item entity
type Item struct {
	ID          string                 `json:"id"`
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Tags        []string               `json:"tags"`
	Metadata    map[string]interface{} `json:"metadata"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

// CreateItemInput represents input for creating an item
type CreateItemInput struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Tags        []string               `json:"tags"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// Validate validates CreateItemInput
func (i *CreateItemInput) Validate() error {
	if i.Name == "" {
		return errors.New("name is required")
	}

	if len(i.Name) > 255 {
		return errors.New("name must not exceed 255 characters")
	}

	if len(i.Description) > 2000 {
		return errors.New("description must not exceed 2000 characters")
	}

	if len(i.Tags) > 10 {
		return errors.New("maximum 10 tags allowed")
	}

	for _, tag := range i.Tags {
		if len(tag) > 50 {
			return errors.New("tag must not exceed 50 characters")
		}
	}

	return nil
}

// UpdateItemInput represents input for updating an item
type UpdateItemInput struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	Tags        []string               `json:"tags"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// Validate validates UpdateItemInput
func (i *UpdateItemInput) Validate() error {
	input := CreateItemInput{
		Name:        i.Name,
		Description: i.Description,
		Tags:        i.Tags,
		Metadata:    i.Metadata,
	}
	return input.Validate()
}

// PatchItemInput represents input for partial update
type PatchItemInput struct {
	Name        *string                 `json:"name,omitempty"`
	Description *string                 `json:"description,omitempty"`
	Tags        []string                `json:"tags,omitempty"`
	Metadata    map[string]interface{}  `json:"metadata,omitempty"`
}
```

---

### 2.8. Middleware

**File:** `internal/http/middleware/logger.go`

```go
package middleware

import (
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5/middleware"
)

// Logger is a middleware that logs HTTP requests
func Logger(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		defer func() {
			log.Printf(
				"method=%s path=%s status=%d duration=%s request_id=%s",
				r.Method,
				r.URL.Path,
				ww.Status(),
				time.Since(start),
				middleware.GetReqID(r.Context()),
			)
		}()

		next.ServeHTTP(ww, r)
	})
}
```

**File:** `internal/http/middleware/cors.go`

```go
package middleware

import (
	"net/http"
)

// CORS middleware handles Cross-Origin Resource Sharing
func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}
```

---

### 2.9. Makefile

**File:** `Makefile`

```makefile
.PHONY: help build test lint run docker-build

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

deps: ## Install dependencies
	go mod download
	go mod tidy

build: ## Build the application
	go build -o bin/api cmd/api/main.go

test: ## Run tests
	go test -v -race -coverprofile=coverage.out ./...

test-coverage: test ## Run tests with coverage report
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

lint: ## Run linter
	golangci-lint run

run: ## Run the application
	go run cmd/api/main.go

dev: ## Run in development mode with hot reload
	air

docker-build: ## Build Docker image
	docker build -t app-base-go-react-backend:latest -f Dockerfile .

clean: ## Clean build artifacts
	rm -rf bin/
	rm -f coverage.out coverage.html
```

---

## 3. Frontend (React + TypeScript) - Референсная реализация

### 3.1. Структура проекта

```
frontend/
├── src/
│   ├── api/
│   │   ├── client.ts            # API client
│   │   ├── items.ts             # Items API
│   │   └── types.ts             # API types
│   ├── components/
│   │   ├── ItemList/
│   │   │   ├── ItemList.tsx
│   │   │   ├── ItemList.test.tsx
│   │   │   └── ItemList.module.css
│   │   ├── ItemForm/
│   │   │   ├── ItemForm.tsx
│   │   │   └── ItemForm.test.tsx
│   │   └── common/
│   │       ├── Button/
│   │       ├── Input/
│   │       └── Card/
│   ├── pages/
│   │   ├── HomePage.tsx
│   │   ├── ItemsPage.tsx
│   │   └── ItemDetailPage.tsx
│   ├── hooks/
│   │   ├── useItems.ts
│   │   └── useItem.ts
│   ├── utils/
│   │   ├── validation.ts
│   │   └── formatting.ts
│   ├── App.tsx
│   ├── main.tsx
│   └── vite-env.d.ts
├── public/
├── package.json
├── tsconfig.json
├── vite.config.ts
└── Dockerfile
```

---

### 3.2. API Client

**File:** `src/api/client.ts`

```typescript
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';

export class APIError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public errorCode?: string,
    public details?: unknown
  ) {
    super(message);
    this.name = 'APIError';
  }
}

export async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));

    throw new APIError(
      errorData.error?.message || 'Request failed',
      response.status,
      errorData.error?.code,
      errorData.error?.details
    );
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return undefined as T;
  }

  return response.json();
}
```

**File:** `src/api/types.ts`

```typescript
export interface Item {
  id: string;
  name: string;
  description: string;
  tags: string[];
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface CreateItemInput {
  name: string;
  description?: string;
  tags?: string[];
  metadata?: Record<string, unknown>;
}

export interface UpdateItemInput {
  name: string;
  description?: string;
  tags?: string[];
  metadata?: Record<string, unknown>;
}

export interface PaginationParams {
  page?: number;
  limit?: number;
  tags?: string;
  search?: string;
  sort?: string;
  order?: 'asc' | 'desc';
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    total_pages: number;
  };
}
```

**File:** `src/api/items.ts`

```typescript
import { apiRequest } from './client';
import type {
  Item,
  CreateItemInput,
  UpdateItemInput,
  PaginatedResponse,
  PaginationParams,
} from './types';

export async function fetchItems(
  params: PaginationParams = {}
): Promise<PaginatedResponse<Item>> {
  const queryParams = new URLSearchParams();

  if (params.page) queryParams.set('page', params.page.toString());
  if (params.limit) queryParams.set('limit', params.limit.toString());
  if (params.tags) queryParams.set('tags', params.tags);
  if (params.search) queryParams.set('search', params.search);
  if (params.sort) queryParams.set('sort', params.sort);
  if (params.order) queryParams.set('order', params.order);

  const query = queryParams.toString();
  const endpoint = `/items${query ? `?${query}` : ''}`;

  return apiRequest<PaginatedResponse<Item>>(endpoint);
}

export async function fetchItem(id: string): Promise<Item> {
  return apiRequest<Item>(`/items/${id}`);
}

export async function createItem(input: CreateItemInput): Promise<Item> {
  return apiRequest<Item>('/items', {
    method: 'POST',
    body: JSON.stringify(input),
  });
}

export async function updateItem(
  id: string,
  input: UpdateItemInput
): Promise<Item> {
  return apiRequest<Item>(`/items/${id}`, {
    method: 'PUT',
    body: JSON.stringify(input),
  });
}

export async function patchItem(
  id: string,
  input: Partial<UpdateItemInput>
): Promise<Item> {
  return apiRequest<Item>(`/items/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  });
}

export async function deleteItem(id: string): Promise<void> {
  return apiRequest<void>(`/items/${id}`, {
    method: 'DELETE',
  });
}
```

---

### 3.3. React Hooks

**File:** `src/hooks/useItems.ts`

```typescript
import { useState, useEffect } from 'react';
import { fetchItems } from '../api/items';
import type { Item, PaginationParams, PaginatedResponse } from '../api/types';

export function useItems(params: PaginationParams = {}) {
  const [data, setData] = useState<PaginatedResponse<Item> | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    const loadItems = async () => {
      try {
        setLoading(true);
        setError(null);

        const result = await fetchItems(params);

        if (!cancelled) {
          setData(result);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err : new Error('Failed to load items'));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    loadItems();

    return () => {
      cancelled = true;
    };
  }, [JSON.stringify(params)]);

  return { data, loading, error };
}
```

---

### 3.4. React Components

**File:** `src/components/ItemList/ItemList.tsx`

```typescript
import React from 'react';
import type { Item } from '../../api/types';
import styles from './ItemList.module.css';

interface ItemListProps {
  items: Item[];
  onItemClick?: (item: Item) => void;
  onDeleteClick?: (item: Item) => void;
}

export function ItemList({ items, onItemClick, onDeleteClick }: ItemListProps) {
  if (items.length === 0) {
    return (
      <div className={styles.empty}>
        <p>No items found</p>
      </div>
    );
  }

  return (
    <ul className={styles.list}>
      {items.map((item) => (
        <li key={item.id} className={styles.item}>
          <div
            className={styles.content}
            onClick={() => onItemClick?.(item)}
            role="button"
            tabIndex={0}
          >
            <h3 className={styles.name}>{item.name}</h3>
            <p className={styles.description}>{item.description}</p>
            {item.tags.length > 0 && (
              <div className={styles.tags}>
                {item.tags.map((tag) => (
                  <span key={tag} className={styles.tag}>
                    {tag}
                  </span>
                ))}
              </div>
            )}
          </div>
          {onDeleteClick && (
            <button
              className={styles.deleteButton}
              onClick={(e) => {
                e.stopPropagation();
                onDeleteClick(item);
              }}
              data-testid={`delete-${item.name}`}
            >
              Delete
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
```

**File:** `src/components/ItemList/ItemList.test.tsx`

```typescript
import { render, screen } from '@testing-library/react';
import { ItemList } from './ItemList';
import type { Item } from '../../api/types';

describe('ItemList', () => {
  const mockItems: Item[] = [
    {
      id: '1',
      name: 'Item 1',
      description: 'Description 1',
      tags: ['tag1'],
      metadata: {},
      created_at: '2025-10-23T10:00:00Z',
      updated_at: '2025-10-23T10:00:00Z',
    },
    {
      id: '2',
      name: 'Item 2',
      description: 'Description 2',
      tags: [],
      metadata: {},
      created_at: '2025-10-23T10:00:00Z',
      updated_at: '2025-10-23T10:00:00Z',
    },
  ];

  test('renders list of items', () => {
    render(<ItemList items={mockItems} />);

    expect(screen.getByText('Item 1')).toBeInTheDocument();
    expect(screen.getByText('Item 2')).toBeInTheDocument();
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
  });

  test('displays empty state when no items', () => {
    render(<ItemList items={[]} />);

    expect(screen.getByText(/no items found/i)).toBeInTheDocument();
    expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
  });

  test('calls onItemClick when item is clicked', () => {
    const onItemClick = jest.fn();
    render(<ItemList items={mockItems} onItemClick={onItemClick} />);

    const firstItem = screen.getByText('Item 1');
    firstItem.click();

    expect(onItemClick).toHaveBeenCalledWith(mockItems[0]);
  });

  test('calls onDeleteClick when delete button is clicked', () => {
    const onDeleteClick = jest.fn();
    render(<ItemList items={mockItems} onDeleteClick={onDeleteClick} />);

    const deleteButton = screen.getByTestId('delete-Item 1');
    deleteButton.click();

    expect(onDeleteClick).toHaveBeenCalledWith(mockItems[0]);
  });
});
```

---

## 4. Dockerfile Examples

### 4.1. Backend Dockerfile

**File:** `backend/Dockerfile`

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o api cmd/api/main.go

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/api .

EXPOSE 8080

CMD ["./api"]
```

### 4.2. Frontend Dockerfile

**File:** `frontend/Dockerfile`

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./
RUN npm ci

# Copy source code
COPY . .

# Build app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**File:** `frontend/nginx.conf`

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Proxy API requests to backend
    location /api/ {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Serve frontend
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 5. Связанные документы

- [API-контракты](api-contracts.md)
- [Спецификация тестирования](testing-specification.md)
- [Шаблон сервиса](service-template-app-base-go-react.md)
- [CI/CD Pipeline](ci-cd-pipeline.md)
