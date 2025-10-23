# Спецификация тестирования

**Статус документа:** Draft · **Аудитория:** QA, разработчики backend/frontend, платформенная команда.

## 1. Обзор и философия тестирования

Документ определяет стратегию и конкретные тестовые сценарии для платформы `soft-yt`. Следуем Test-Driven Development (TDD): тесты пишутся ДО реализации функциональности.

### 1.1. Пирамида тестирования

```
           /\
          /  \     E2E Tests (10%)
         /____\
        /      \   Integration Tests (30%)
       /________\
      /          \ Unit Tests (60%)
     /____________\
```

**Распределение усилий:**
- **Unit Tests (60%):** Тестирование отдельных функций/компонентов в изоляции
- **Integration Tests (30%):** Тестирование взаимодействия между компонентами
- **E2E Tests (10%):** Тестирование полных пользовательских сценариев

### 1.2. Цели качества

- **Code Coverage:** минимум 80% для backend, 70% для frontend
- **Test Execution Time:** полный прогон unit-тестов < 2 минуты
- **Test Execution Time:** полный прогон интеграционных тестов < 10 минут
- **Test Execution Time:** полный прогон E2E тестов < 30 минут
- **Flaky Tests:** максимум 1% от общего количества тестов

---

## 2. Backend Testing (Go)

### 2.1. Unit Tests

#### 2.1.1. Тестирование HTTP Handlers

**Test Suite:** `internal/http/handlers_test.go`

**TS-001: Health Check Handler - Success**

```go
func TestHealthCheckHandler_Success(t *testing.T) {
    // Arrange
    req := httptest.NewRequest("GET", "/healthz", nil)
    w := httptest.NewRecorder()
    handler := NewHealthHandler()

    // Act
    handler.ServeHTTP(w, req)

    // Assert
    assert.Equal(t, http.StatusOK, w.Code)

    var response HealthResponse
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    assert.Equal(t, "healthy", response.Status)
    assert.NotEmpty(t, response.Timestamp)
}
```

**Expected Result:**
- Статус код 200
- JSON с полем `status: "healthy"`
- Timestamp в ISO 8601 формате

**Priority:** P0 (критический)

---

**TS-002: Health Check Handler - Service Unavailable**

```go
func TestHealthCheckHandler_ServiceUnavailable(t *testing.T) {
    // Arrange
    req := httptest.NewRequest("GET", "/healthz", nil)
    w := httptest.NewRecorder()

    // Симулируем недоступность критического сервиса
    handler := NewHealthHandler(WithDatabaseCheck(failingDBCheck))

    // Act
    handler.ServeHTTP(w, req)

    // Assert
    assert.Equal(t, http.StatusServiceUnavailable, w.Code)

    var response HealthResponse
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    assert.Equal(t, "unhealthy", response.Status)
}
```

**Expected Result:**
- Статус код 503
- JSON с полем `status: "unhealthy"`

**Priority:** P0 (критический)

---

**TS-003: Create Item - Valid Input**

```go
func TestCreateItemHandler_ValidInput(t *testing.T) {
    // Arrange
    itemService := NewMockItemService()
    handler := NewItemHandler(itemService)

    payload := `{
        "name": "Test Item",
        "description": "Test description",
        "tags": ["tag1", "tag2"]
    }`

    req := httptest.NewRequest("POST", "/api/v1/items", strings.NewReader(payload))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    // Act
    handler.CreateItem(w, req)

    // Assert
    assert.Equal(t, http.StatusCreated, w.Code)

    var response ItemResponse
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)
    assert.NotEmpty(t, response.ID)
    assert.Equal(t, "Test Item", response.Name)
    assert.Equal(t, "Test description", response.Description)
    assert.Len(t, response.Tags, 2)
    assert.NotEmpty(t, response.CreatedAt)
    assert.NotEmpty(t, response.UpdatedAt)

    // Verify service was called
    assert.True(t, itemService.CreateCalled)
}
```

**Expected Result:**
- Статус код 201
- Item создан с UUID
- Все поля соответствуют переданным данным
- Timestamps установлены

**Priority:** P0 (критический)

---

**TS-004: Create Item - Invalid Input (Empty Name)**

```go
func TestCreateItemHandler_EmptyName(t *testing.T) {
    // Arrange
    itemService := NewMockItemService()
    handler := NewItemHandler(itemService)

    payload := `{"name": "", "description": "Test"}`
    req := httptest.NewRequest("POST", "/api/v1/items", strings.NewReader(payload))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    // Act
    handler.CreateItem(w, req)

    // Assert
    assert.Equal(t, http.StatusBadRequest, w.Code)

    var errorResponse ErrorResponse
    err := json.Unmarshal(w.Body.Bytes(), &errorResponse)
    assert.NoError(t, err)
    assert.Equal(t, "VALIDATION_ERROR", errorResponse.Error.Code)
    assert.Contains(t, errorResponse.Error.Details, ValidationError{
        Field: "name",
        Issue: "must not be empty",
    })

    // Verify service was NOT called
    assert.False(t, itemService.CreateCalled)
}
```

**Expected Result:**
- Статус код 400
- Ошибка валидации с детальным описанием
- Service не вызван

**Priority:** P0 (критический)

---

**TS-005: Get Items - Pagination**

```go
func TestGetItemsHandler_Pagination(t *testing.T) {
    // Arrange
    items := generateMockItems(50) // Генерируем 50 items
    itemService := NewMockItemService(WithItems(items))
    handler := NewItemHandler(itemService)

    req := httptest.NewRequest("GET", "/api/v1/items?page=2&limit=20", nil)
    w := httptest.NewRecorder()

    // Act
    handler.GetItems(w, req)

    // Assert
    assert.Equal(t, http.StatusOK, w.Code)

    var response ItemsResponse
    err := json.Unmarshal(w.Body.Bytes(), &response)
    assert.NoError(t, err)

    assert.Len(t, response.Data, 20)
    assert.Equal(t, 2, response.Pagination.Page)
    assert.Equal(t, 20, response.Pagination.Limit)
    assert.Equal(t, 50, response.Pagination.Total)
    assert.Equal(t, 3, response.Pagination.TotalPages)
}
```

**Expected Result:**
- Возвращает вторую страницу (20 items)
- Pagination metadata корректна

**Priority:** P1 (высокий)

---

#### 2.1.2. Тестирование бизнес-логики

**Test Suite:** `internal/service/item_service_test.go`

**TS-006: Item Service - Create Item**

```go
func TestItemService_CreateItem(t *testing.T) {
    // Arrange
    repo := NewMockItemRepository()
    service := NewItemService(repo)

    input := CreateItemInput{
        Name:        "Test Item",
        Description: "Description",
        Tags:        []string{"tag1"},
    }

    // Act
    item, err := service.CreateItem(context.Background(), input)

    // Assert
    assert.NoError(t, err)
    assert.NotEmpty(t, item.ID)
    assert.Equal(t, input.Name, item.Name)
    assert.True(t, repo.SaveCalled)
}
```

**Priority:** P0 (критический)

---

**TS-007: Item Service - Validate Tags Limit**

```go
func TestItemService_CreateItem_TooManyTags(t *testing.T) {
    // Arrange
    repo := NewMockItemRepository()
    service := NewItemService(repo)

    // Создаем 11 тегов (превышает лимит в 10)
    tags := make([]string, 11)
    for i := range tags {
        tags[i] = fmt.Sprintf("tag%d", i)
    }

    input := CreateItemInput{
        Name: "Test Item",
        Tags: tags,
    }

    // Act
    _, err := service.CreateItem(context.Background(), input)

    // Assert
    assert.Error(t, err)
    assert.Contains(t, err.Error(), "maximum 10 tags allowed")
    assert.False(t, repo.SaveCalled)
}
```

**Priority:** P1 (высокий)

---

#### 2.1.3. Тестирование Configuration

**Test Suite:** `internal/config/config_test.go`

**TS-008: Config Loading - Valid Environment Variables**

```go
func TestLoadConfig_ValidEnv(t *testing.T) {
    // Arrange
    os.Setenv("APP_PORT", "8080")
    os.Setenv("APP_LOG_LEVEL", "debug")
    defer os.Clearenv()

    // Act
    cfg, err := LoadConfig()

    // Assert
    assert.NoError(t, err)
    assert.Equal(t, 8080, cfg.Port)
    assert.Equal(t, "debug", cfg.LogLevel)
}
```

**Priority:** P1 (высокий)

---

**TS-009: Config Loading - Default Values**

```go
func TestLoadConfig_Defaults(t *testing.T) {
    // Arrange
    os.Clearenv()

    // Act
    cfg, err := LoadConfig()

    // Assert
    assert.NoError(t, err)
    assert.Equal(t, 8080, cfg.Port) // Default port
    assert.Equal(t, "info", cfg.LogLevel) // Default log level
}
```

**Priority:** P2 (средний)

---

### 2.2. Integration Tests

#### 2.2.1. Database Integration

**Test Suite:** `test/integration/database_test.go`

**TS-010: Database - Item CRUD Operations**

```go
func TestDatabase_ItemCRUD(t *testing.T) {
    // Arrange
    db := setupTestDatabase(t)
    defer cleanupTestDatabase(t, db)

    repo := NewItemRepository(db)
    ctx := context.Background()

    // Act & Assert - Create
    item := &Item{
        ID:          uuid.New().String(),
        Name:        "Test Item",
        Description: "Description",
        Tags:        []string{"tag1"},
    }

    err := repo.Save(ctx, item)
    assert.NoError(t, err)

    // Act & Assert - Read
    retrieved, err := repo.GetByID(ctx, item.ID)
    assert.NoError(t, err)
    assert.Equal(t, item.Name, retrieved.Name)

    // Act & Assert - Update
    retrieved.Name = "Updated Name"
    err = repo.Update(ctx, retrieved)
    assert.NoError(t, err)

    updated, err := repo.GetByID(ctx, item.ID)
    assert.NoError(t, err)
    assert.Equal(t, "Updated Name", updated.Name)

    // Act & Assert - Delete
    err = repo.Delete(ctx, item.ID)
    assert.NoError(t, err)

    _, err = repo.GetByID(ctx, item.ID)
    assert.Error(t, err)
    assert.True(t, errors.Is(err, ErrNotFound))
}
```

**Test Data:** Используется реальная PostgreSQL (testcontainers)

**Priority:** P0 (критический)

---

#### 2.2.2. API Integration Tests

**Test Suite:** `test/integration/api_test.go`

**TS-011: API Integration - Full Item Lifecycle**

```go
func TestAPI_ItemLifecycle(t *testing.T) {
    // Arrange
    testServer := setupTestServer(t)
    defer testServer.Close()

    client := testServer.Client()
    baseURL := testServer.URL

    // Act & Assert - Create Item
    createPayload := `{"name":"Integration Test Item","tags":["test"]}`
    resp, err := client.Post(
        baseURL+"/api/v1/items",
        "application/json",
        strings.NewReader(createPayload),
    )
    assert.NoError(t, err)
    assert.Equal(t, http.StatusCreated, resp.StatusCode)

    var createdItem ItemResponse
    json.NewDecoder(resp.Body).Decode(&createdItem)
    itemID := createdItem.ID

    // Act & Assert - Get Item
    resp, err = client.Get(baseURL + "/api/v1/items/" + itemID)
    assert.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    // Act & Assert - Update Item
    updatePayload := `{"name":"Updated Item"}`
    req, _ := http.NewRequest(
        "PATCH",
        baseURL+"/api/v1/items/"+itemID,
        strings.NewReader(updatePayload),
    )
    req.Header.Set("Content-Type", "application/json")
    resp, err = client.Do(req)
    assert.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    // Act & Assert - Delete Item
    req, _ = http.NewRequest("DELETE", baseURL+"/api/v1/items/"+itemID, nil)
    resp, err = client.Do(req)
    assert.NoError(t, err)
    assert.Equal(t, http.StatusNoContent, resp.StatusCode)

    // Verify deletion
    resp, err = client.Get(baseURL + "/api/v1/items/" + itemID)
    assert.NoError(t, err)
    assert.Equal(t, http.StatusNotFound, resp.StatusCode)
}
```

**Test Data:** Изолированная база данных для интеграционных тестов

**Priority:** P0 (критический)

---

### 2.3. Performance Tests

**TS-012: Load Test - GET /api/v1/items**

**Tool:** k6 или vegeta

**Scenario:**
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '30s', target: 50 },  // Ramp up to 50 users
        { duration: '1m', target: 50 },   // Stay at 50 users
        { duration: '30s', target: 100 }, // Ramp up to 100 users
        { duration: '1m', target: 100 },  // Stay at 100 users
        { duration: '30s', target: 0 },   // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<200'], // 95% requests < 200ms
        http_req_failed: ['rate<0.01'],   // Error rate < 1%
    },
};

export default function() {
    let response = http.get('http://localhost:8080/api/v1/items?page=1&limit=20');

    check(response, {
        'status is 200': (r) => r.status === 200,
        'response time < 200ms': (r) => r.timings.duration < 200,
    });

    sleep(1);
}
```

**Acceptance Criteria:**
- p95 latency < 200ms
- Error rate < 1%
- Throughput > 100 RPS на одном инстансе

**Priority:** P1 (высокий)

---

## 3. Frontend Testing (React + TypeScript)

### 3.1. Component Unit Tests

**Test Suite:** `frontend/src/components/ItemList.test.tsx`

**TS-013: ItemList Component - Renders Items**

```typescript
import { render, screen } from '@testing-library/react';
import { ItemList } from './ItemList';

describe('ItemList', () => {
    test('TS-013: renders list of items', () => {
        // Arrange
        const items = [
            { id: '1', name: 'Item 1', description: 'Desc 1', tags: [] },
            { id: '2', name: 'Item 2', description: 'Desc 2', tags: [] },
        ];

        // Act
        render(<ItemList items={items} />);

        // Assert
        expect(screen.getByText('Item 1')).toBeInTheDocument();
        expect(screen.getByText('Item 2')).toBeInTheDocument();
        expect(screen.getAllByRole('listitem')).toHaveLength(2);
    });
});
```

**Priority:** P0 (критический)

---

**TS-014: ItemList Component - Empty State**

```typescript
test('TS-014: displays empty state when no items', () => {
    // Arrange
    const items = [];

    // Act
    render(<ItemList items={items} />);

    // Assert
    expect(screen.getByText(/no items found/i)).toBeInTheDocument();
    expect(screen.queryByRole('listitem')).not.toBeInTheDocument();
});
```

**Priority:** P1 (высокий)

---

**TS-015: ItemForm Component - Validation**

```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { ItemForm } from './ItemForm';

test('TS-015: validates required name field', async () => {
    // Arrange
    const onSubmit = jest.fn();
    render(<ItemForm onSubmit={onSubmit} />);

    // Act
    const submitButton = screen.getByRole('button', { name: /submit/i });
    fireEvent.click(submitButton);

    // Assert
    await waitFor(() => {
        expect(screen.getByText(/name is required/i)).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();
});
```

**Priority:** P0 (критический)

---

### 3.2. API Client Tests

**Test Suite:** `frontend/src/api/items.test.ts`

**TS-016: API Client - Fetch Items Success**

```typescript
import { fetchItems } from './items';
import { rest } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
    rest.get('/api/v1/items', (req, res, ctx) => {
        return res(ctx.json({
            data: [
                { id: '1', name: 'Item 1', description: '', tags: [] },
            ],
            pagination: { page: 1, limit: 20, total: 1, total_pages: 1 },
        }));
    })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test('TS-016: fetches items successfully', async () => {
    // Act
    const result = await fetchItems({ page: 1, limit: 20 });

    // Assert
    expect(result.data).toHaveLength(1);
    expect(result.data[0].name).toBe('Item 1');
    expect(result.pagination.total).toBe(1);
});
```

**Priority:** P0 (критический)

---

**TS-017: API Client - Handle Network Error**

```typescript
test('TS-017: handles network error gracefully', async () => {
    // Arrange
    server.use(
        rest.get('/api/v1/items', (req, res, ctx) => {
            return res.networkError('Failed to connect');
        })
    );

    // Act & Assert
    await expect(fetchItems({ page: 1, limit: 20 }))
        .rejects
        .toThrow('Network error');
});
```

**Priority:** P1 (высокий)

---

### 3.3. E2E Tests

**Test Suite:** `frontend/e2e/items.spec.ts` (Playwright)

**TS-018: E2E - Create and View Item**

```typescript
import { test, expect } from '@playwright/test';

test('TS-018: user can create and view item', async ({ page }) => {
    // Given: User navigates to items page
    await page.goto('http://localhost:5173/items');

    // When: User clicks create button
    await page.click('button:has-text("Create Item")');

    // And: Fills the form
    await page.fill('input[name="name"]', 'E2E Test Item');
    await page.fill('textarea[name="description"]', 'E2E Description');
    await page.fill('input[name="tags"]', 'e2e, test');

    // And: Submits the form
    await page.click('button[type="submit"]');

    // Then: Item appears in the list
    await expect(page.locator('text=E2E Test Item')).toBeVisible();
    await expect(page.locator('text=E2E Description')).toBeVisible();

    // And: Can view item details
    await page.click('text=E2E Test Item');
    await expect(page).toHaveURL(/\/items\/[a-f0-9-]+/);
    await expect(page.locator('h1:has-text("E2E Test Item")')).toBeVisible();
});
```

**Test Data:** Seed database с тестовыми данными

**Priority:** P0 (критический)

---

**TS-019: E2E - Edit Item**

```typescript
test('TS-019: user can edit item', async ({ page }) => {
    // Given: Item exists
    await page.goto('http://localhost:5173/items');
    await page.click('text=Test Item');

    // When: User clicks edit button
    await page.click('button:has-text("Edit")');

    // And: Updates the name
    await page.fill('input[name="name"]', 'Updated Item Name');
    await page.click('button[type="submit"]');

    // Then: Updated name is visible
    await expect(page.locator('h1:has-text("Updated Item Name")')).toBeVisible();

    // And: Success message appears
    await expect(page.locator('text=Item updated successfully')).toBeVisible();
});
```

**Priority:** P1 (высокий)

---

**TS-020: E2E - Delete Item**

```typescript
test('TS-020: user can delete item', async ({ page }) => {
    // Given: Item exists
    await page.goto('http://localhost:5173/items');
    const itemName = 'Item to Delete';
    await expect(page.locator(`text=${itemName}`)).toBeVisible();

    // When: User clicks delete button
    await page.click(`[data-testid="delete-${itemName}"]`);

    // And: Confirms deletion
    await page.click('button:has-text("Confirm")');

    // Then: Item is removed from list
    await expect(page.locator(`text=${itemName}`)).not.toBeVisible();

    // And: Success message appears
    await expect(page.locator('text=Item deleted successfully')).toBeVisible();
});
```

**Priority:** P1 (высокий)

---

## 4. CI/CD Pipeline Tests

### 4.1. GitHub Actions Workflow Tests

**TS-021: CI - Backend Tests Pass**

**Acceptance Criteria:**
- Все unit тесты проходят успешно
- Code coverage >= 80%
- Линтер не выдает ошибок
- Build завершается без ошибок

**Configuration:** `.github/workflows/ci.yml`

```yaml
- name: Run backend tests
  run: |
    cd backend
    go test -v -race -coverprofile=coverage.out ./...
    go tool cover -func=coverage.out

- name: Check coverage
  run: |
    coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
    if (( $(echo "$coverage < 80" | bc -l) )); then
      echo "Coverage $coverage% is below 80%"
      exit 1
    fi
```

**Priority:** P0 (критический)

---

**TS-022: CI - Frontend Tests Pass**

**Acceptance Criteria:**
- Все unit тесты проходят успешно
- Code coverage >= 70%
- ESLint не выдает ошибок
- TypeScript компилируется без ошибок
- Build завершается без ошибок

**Configuration:**

```yaml
- name: Run frontend tests
  run: |
    cd frontend
    npm ci
    npm run lint
    npm run type-check
    npm run test:coverage
    npm run build
```

**Priority:** P0 (критический)

---

**TS-023: CI - Docker Build Success**

**Acceptance Criteria:**
- Backend image собирается успешно
- Frontend image собирается успешно
- Images публикуются в GHCR
- Images подписаны через Cosign

**Priority:** P0 (критический)

---

### 4.2. GitOps Tests

**TS-024: GitOps - Argo CD Sync Success**

**Scenario:**
1. Обновить image tag в `infra-gitops`
2. Дождаться синхронизации Argo CD (автоматической или ручной)
3. Проверить, что pod с новым image запущен
4. Проверить, что health check проходит

**Acceptance Criteria:**
- Sync завершается без ошибок
- Новый pod в состоянии Running
- Health checks успешны
- Старый pod корректно terminated

**Priority:** P0 (критический)

---

## 5. Security Tests

**TS-025: Security - Input Sanitization**

```go
func TestSecurity_XSSPrevention(t *testing.T) {
    // Arrange
    handler := NewItemHandler(NewMockItemService())
    payload := `{"name":"<script>alert('xss')</script>","description":"test"}`

    req := httptest.NewRequest("POST", "/api/v1/items", strings.NewReader(payload))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    // Act
    handler.CreateItem(w, req)

    // Assert
    assert.Equal(t, http.StatusCreated, w.Code)

    var response ItemResponse
    json.Unmarshal(w.Body.Bytes(), &response)

    // Verify script tags are escaped or removed
    assert.NotContains(t, response.Name, "<script>")
}
```

**Priority:** P0 (критический)

---

**TS-026: Security - SQL Injection Prevention**

```go
func TestSecurity_SQLInjection(t *testing.T) {
    // Arrange
    db := setupTestDatabase(t)
    defer cleanupTestDatabase(t, db)

    repo := NewItemRepository(db)
    ctx := context.Background()

    maliciousName := "'; DROP TABLE items; --"

    item := &Item{
        ID:   uuid.New().String(),
        Name: maliciousName,
    }

    // Act
    err := repo.Save(ctx, item)

    // Assert
    assert.NoError(t, err)

    // Verify table still exists
    var count int
    err = db.QueryRow("SELECT COUNT(*) FROM items").Scan(&count)
    assert.NoError(t, err, "Table should still exist")
}
```

**Priority:** P0 (критический)

---

**TS-027: Security - Rate Limiting**

```go
func TestSecurity_RateLimit(t *testing.T) {
    // Arrange
    server := setupTestServerWithRateLimiting(t)
    defer server.Close()

    client := server.Client()

    // Act - Send 101 requests (limit is 100)
    var lastResponse *http.Response
    for i := 0; i < 101; i++ {
        resp, _ := client.Get(server.URL + "/api/v1/items")
        if i == 100 {
            lastResponse = resp
        }
    }

    // Assert
    assert.Equal(t, http.StatusTooManyRequests, lastResponse.StatusCode)
    assert.Equal(t, "RATE_LIMIT_EXCEEDED", extractErrorCode(lastResponse))
}
```

**Priority:** P1 (высокий)

---

## 6. Test Data Management

### 6.1. Test Fixtures

**Location:** `test/fixtures/`

**items.json:**
```json
[
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Fixture Item 1",
        "description": "Test fixture",
        "tags": ["test", "fixture"],
        "created_at": "2025-10-23T10:00:00Z",
        "updated_at": "2025-10-23T10:00:00Z"
    }
]
```

### 6.2. Database Seeding

**Script:** `test/seed/seed.go`

```go
func SeedTestData(db *sql.DB) error {
    fixtures, err := loadFixtures("test/fixtures/items.json")
    if err != nil {
        return err
    }

    for _, item := range fixtures {
        _, err := db.Exec(
            "INSERT INTO items (id, name, description, tags, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6)",
            item.ID, item.Name, item.Description, pq.Array(item.Tags), item.CreatedAt, item.UpdatedAt,
        )
        if err != nil {
            return err
        }
    }

    return nil
}
```

---

## 7. Test Environment Setup

### 7.1. Local Development

**Prerequisites:**
- Docker Desktop / Colima
- PostgreSQL test database
- Go 1.22+
- Node.js 20+

**Setup:**
```bash
# Backend
cd backend
make test-setup  # Создает test database
make test        # Запускает тесты

# Frontend
cd frontend
npm install
npm test
```

### 7.2. CI Environment

**GitHub Actions Matrix:**
```yaml
strategy:
  matrix:
    go-version: ['1.22', '1.23']
    node-version: ['20', '21']
    os: [ubuntu-latest, macos-latest]
```

---

## 8. Continuous Testing Strategy

### 8.1. Pre-commit Hooks

**Tool:** Husky + lint-staged

```json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged",
      "pre-push": "npm test"
    }
  },
  "lint-staged": {
    "*.go": ["go fmt", "go vet"],
    "*.ts": ["eslint --fix", "prettier --write"]
  }
}
```

### 8.2. Pull Request Checks

**Required Checks:**
- Unit tests (backend + frontend)
- Integration tests
- Linters
- Code coverage threshold
- Security scan (Snyk, Dependabot)

### 8.3. Scheduled Tests

**Nightly:**
- Full E2E test suite
- Performance tests
- Security scans

**Weekly:**
- Dependency updates
- Database migration tests
- Chaos engineering tests (опционально)

---

## 9. Test Reporting

### 9.1. Coverage Reports

**Tools:**
- Backend: `go tool cover`
- Frontend: Istanbul/nyc

**Format:** HTML + JSON для CI интеграции

### 9.2. Test Results Dashboard

**Integration:** GitHub Actions + Codecov

**Metrics:**
- Total tests
- Passed/Failed/Skipped
- Coverage percentage
- Test execution time
- Flaky tests

---

## 10. Acceptance Criteria Summary

Для выхода в продакшен все критерии должны быть выполнены:

- [ ] AC-001 до AC-046 (из API Contracts) - все проходят
- [ ] TS-001 до TS-027 - все тесты реализованы и проходят
- [ ] Backend coverage >= 80%
- [ ] Frontend coverage >= 70%
- [ ] E2E тесты покрывают критические пользовательские сценарии
- [ ] CI/CD pipeline успешно выполняется
- [ ] Security тесты проходят
- [ ] Performance тесты соответствуют SLO (p95 < 200ms)
- [ ] Flaky tests < 1%
- [ ] Документация по тестированию актуальна

---

## 11. Открытые вопросы

- Нужен ли chaos engineering для тестирования отказоустойчивости?
- Какой инструмент использовать для mutation testing?
- Требуется ли visual regression testing для frontend?
- Как часто запускать полный E2E suite?
- Нужна ли интеграция с BDD-фреймворками (Gherkin)?

---

## 12. Связанные документы

- [API-контракты](api-contracts.md) — спецификация API и acceptance criteria
- [Шаблон сервиса](service-template-app-base-go-react.md) — структура проекта
- [CI/CD Pipeline](ci-cd-pipeline.md) — конфигурация автоматизации
- [Примеры реализации](implementation-examples.md) — примеры кода тестов
