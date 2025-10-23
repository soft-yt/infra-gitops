# Test Data Specification

**Статус документа:** Draft · **Аудитория:** QA, разработчики backend/frontend, платформенная команда.

## 1. Обзор

Документ определяет стратегию управления тестовыми данными, структуру fixtures, моков и seed данных для различных уровней тестирования на платформе `soft-yt`.

**Принципы:**
- Тестовые данные версионируются вместе с кодом
- Fixtures переиспользуются между тестами
- Тестовые данные изолированы и не влияют друг на друга
- Sensitive данные не хранятся в fixtures

---

## 2. Типы тестовых данных

### 2.1. Static Fixtures

**Назначение:** Предопределенные наборы данных для unit и integration тестов

**Location:** `test/fixtures/`

**Формат:** JSON, YAML

**Характеристики:**
- Не изменяются во время теста
- Версионируются в Git
- Используются для проверки edge cases

### 2.2. Generated Test Data

**Назначение:** Динамически генерируемые данные для тестов

**Location:** `test/generators/` или `test/factories/`

**Характеристики:**
- Генерируются во время выполнения теста
- Используют библиотеки (faker, etc.)
- Позволяют создавать случайные, но валидные данные

### 2.3. Seed Data

**Назначение:** Начальные данные для локальной разработки и E2E тестов

**Location:** `test/seed/`

**Характеристики:**
- Создают консистентное начальное состояние БД
- Используются для manual testing и E2E
- Могут содержать связанные entities

### 2.4. Mock Data

**Назначение:** Данные для замены внешних зависимостей

**Location:** В тестовых файлах или `test/mocks/`

**Характеристики:**
- Имитируют ответы внешних API
- Используются в unit тестах
- Могут быть success и error сценарии

---

## 3. Структура Test Data репозитория

```
backend/
└── test/
    ├── fixtures/                 # Static fixtures
    │   ├── items/
    │   │   ├── valid_items.json
    │   │   ├── invalid_items.json
    │   │   └── edge_cases.json
    │   ├── users/
    │   │   └── users.json
    │   └── common/
    │       └── error_responses.json
    │
    ├── factories/                # Test data generators
    │   ├── item_factory.go
    │   ├── user_factory.go
    │   └── factory_helpers.go
    │
    ├── seed/                     # Database seeding
    │   ├── seed.go
    │   ├── dev_seed.sql
    │   └── e2e_seed.sql
    │
    ├── mocks/                    # Mock implementations
    │   ├── mock_item_repository.go
    │   ├── mock_item_service.go
    │   └── mock_external_api.go
    │
    └── integration/              # Integration test specific
        ├── testdata/
        └── helpers.go

frontend/
└── src/
    ├── __mocks__/                # Jest mocks
    │   ├── api/
    │   │   └── items.ts
    │   └── handlers.ts           # MSW handlers
    │
    └── __fixtures__/             # Test fixtures
        ├── items.ts
        └── users.ts
```

---

## 4. Backend Test Data (Go)

### 4.1. Static Fixtures для Items

**File:** `test/fixtures/items/valid_items.json`

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Valid Item 1",
    "description": "This is a valid item for testing",
    "tags": ["test", "valid"],
    "metadata": {
      "priority": "high",
      "category": "testing"
    },
    "created_at": "2025-10-23T10:00:00Z",
    "updated_at": "2025-10-23T10:00:00Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Valid Item 2",
    "description": "Another valid item",
    "tags": ["test"],
    "metadata": {},
    "created_at": "2025-10-23T11:00:00Z",
    "updated_at": "2025-10-23T11:00:00Z"
  }
]
```

**File:** `test/fixtures/items/invalid_items.json`

```json
[
  {
    "comment": "Empty name",
    "id": "550e8400-e29b-41d4-a716-446655440010",
    "name": "",
    "description": "Item with empty name",
    "tags": [],
    "metadata": {},
    "expected_error": "VALIDATION_ERROR",
    "expected_field": "name"
  },
  {
    "comment": "Name too long (> 255 chars)",
    "id": "550e8400-e29b-41d4-a716-446655440011",
    "name": "a".repeat(256),
    "description": "Item with too long name",
    "tags": [],
    "metadata": {},
    "expected_error": "VALIDATION_ERROR",
    "expected_field": "name"
  },
  {
    "comment": "Too many tags (> 10)",
    "id": "550e8400-e29b-41d4-a716-446655440012",
    "name": "Item with many tags",
    "description": "Testing tag limit",
    "tags": ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "tag8", "tag9", "tag10", "tag11"],
    "metadata": {},
    "expected_error": "VALIDATION_ERROR",
    "expected_field": "tags"
  }
]
```

**File:** `test/fixtures/items/edge_cases.json`

```json
[
  {
    "comment": "Item with exactly 255 characters in name",
    "id": "550e8400-e29b-41d4-a716-446655440020",
    "name": "a".repeat(255),
    "description": "Edge case: maximum name length",
    "tags": [],
    "metadata": {}
  },
  {
    "comment": "Item with exactly 10 tags",
    "id": "550e8400-e29b-41d4-a716-446655440021",
    "name": "Item with 10 tags",
    "description": "Edge case: maximum tags",
    "tags": ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "tag8", "tag9", "tag10"],
    "metadata": {}
  },
  {
    "comment": "Item with Unicode characters",
    "id": "550e8400-e29b-41d4-a716-446655440022",
    "name": "Тестовый предмет 测试项目 🚀",
    "description": "Edge case: Unicode support",
    "tags": ["unicode", "тест", "测试"],
    "metadata": {
      "key": "значение"
    }
  },
  {
    "comment": "Item with special characters",
    "id": "550e8400-e29b-41d4-a716-446655440023",
    "name": "Item with special chars: @#$%^&*()",
    "description": "Edge case: special characters",
    "tags": ["special-chars"],
    "metadata": {}
  }
]
```

---

### 4.2. Fixture Loader для Go

**File:** `test/fixtures/loader.go`

```go
package fixtures

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// LoadFixture loads a fixture file and unmarshals into target
func LoadFixture(path string, target interface{}) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return err
	}

	data, err := os.ReadFile(absPath)
	if err != nil {
		return err
	}

	return json.Unmarshal(data, target)
}

// LoadItems loads item fixtures
func LoadItems(fixtureName string) ([]Item, error) {
	var items []Item
	path := filepath.Join("test", "fixtures", "items", fixtureName+".json")
	err := LoadFixture(path, &items)
	return items, err
}

// LoadValidItems loads valid item fixtures
func LoadValidItems() ([]Item, error) {
	return LoadItems("valid_items")
}

// LoadInvalidItems loads invalid item fixtures
func LoadInvalidItems() ([]Item, error) {
	return LoadItems("invalid_items")
}

// LoadEdgeCaseItems loads edge case item fixtures
func LoadEdgeCaseItems() ([]Item, error) {
	return LoadItems("edge_cases")
}
```

---

### 4.3. Test Data Factories (Go)

**File:** `test/factories/item_factory.go`

```go
package factories

import (
	"time"

	"github.com/google/uuid"
	"github.com/soft-yt/app-base-go-react/internal/models"
)

// ItemFactory creates test items with customizable fields
type ItemFactory struct {
	item models.Item
}

// NewItemFactory creates a new ItemFactory with default values
func NewItemFactory() *ItemFactory {
	return &ItemFactory{
		item: models.Item{
			ID:          uuid.New().String(),
			Name:        "Test Item",
			Description: "Test description",
			Tags:        []string{},
			Metadata:    make(map[string]interface{}),
			CreatedAt:   time.Now().UTC(),
			UpdatedAt:   time.Now().UTC(),
		},
	}
}

// WithID sets custom ID
func (f *ItemFactory) WithID(id string) *ItemFactory {
	f.item.ID = id
	return f
}

// WithName sets custom name
func (f *ItemFactory) WithName(name string) *ItemFactory {
	f.item.Name = name
	return f
}

// WithDescription sets custom description
func (f *ItemFactory) WithDescription(desc string) *ItemFactory {
	f.item.Description = desc
	return f
}

// WithTags sets custom tags
func (f *ItemFactory) WithTags(tags ...string) *ItemFactory {
	f.item.Tags = tags
	return f
}

// WithMetadata sets custom metadata
func (f *ItemFactory) WithMetadata(metadata map[string]interface{}) *ItemFactory {
	f.item.Metadata = metadata
	return f
}

// WithCreatedAt sets custom creation time
func (f *ItemFactory) WithCreatedAt(t time.Time) *ItemFactory {
	f.item.CreatedAt = t
	return f
}

// Build returns the constructed item
func (f *ItemFactory) Build() models.Item {
	return f.item
}

// BuildPointer returns pointer to the constructed item
func (f *ItemFactory) BuildPointer() *models.Item {
	item := f.Build()
	return &item
}

// Helper functions for common test scenarios

// NewValidItem creates a valid item for testing
func NewValidItem() models.Item {
	return NewItemFactory().Build()
}

// NewItemWithLongName creates item with name at maximum length
func NewItemWithLongName() models.Item {
	longName := make([]byte, 255)
	for i := range longName {
		longName[i] = 'a'
	}
	return NewItemFactory().WithName(string(longName)).Build()
}

// NewItemWithMaxTags creates item with maximum number of tags
func NewItemWithMaxTags() models.Item {
	tags := make([]string, 10)
	for i := range tags {
		tags[i] = fmt.Sprintf("tag%d", i+1)
	}
	return NewItemFactory().WithTags(tags...).Build()
}

// NewItemWithUnicode creates item with Unicode characters
func NewItemWithUnicode() models.Item {
	return NewItemFactory().
		WithName("Тестовый предмет 测试项目 🚀").
		WithDescription("Unicode description: Привет مرحبا 你好").
		WithTags("unicode", "тест", "测试").
		Build()
}
```

**Пример использования в тестах:**

```go
func TestItemService_CreateItem(t *testing.T) {
	// Arrange
	repo := NewMockItemRepository()
	service := NewItemService(repo)

	// Use factory to create test data
	item := factories.NewItemFactory().
		WithName("Custom Test Item").
		WithTags("tag1", "tag2").
		Build()

	// Act
	created, err := service.CreateItem(context.Background(), item)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, item.Name, created.Name)
}

func TestItemValidation_EdgeCases(t *testing.T) {
	tests := []struct {
		name    string
		item    models.Item
		wantErr bool
	}{
		{
			name:    "valid item with max length name",
			item:    factories.NewItemWithLongName(),
			wantErr: false,
		},
		{
			name:    "valid item with max tags",
			item:    factories.NewItemWithMaxTags(),
			wantErr: false,
		},
		{
			name:    "valid item with unicode",
			item:    factories.NewItemWithUnicode(),
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.item.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
```

---

### 4.4. Database Seed Data

**File:** `test/seed/seed.go`

```go
package seed

import (
	"context"
	"database/sql"
	"encoding/json"
	"os"

	"github.com/soft-yt/app-base-go-react/internal/models"
)

// Seeder handles database seeding
type Seeder struct {
	db *sql.DB
}

// NewSeeder creates a new database seeder
func NewSeeder(db *sql.DB) *Seeder {
	return &Seeder{db: db}
}

// SeedItems seeds items from fixture file
func (s *Seeder) SeedItems(fixturePath string) error {
	data, err := os.ReadFile(fixturePath)
	if err != nil {
		return err
	}

	var items []models.Item
	if err := json.Unmarshal(data, &items); err != nil {
		return err
	}

	ctx := context.Background()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx,
		`INSERT INTO items (id, name, description, tags, metadata, created_at, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (id) DO NOTHING`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, item := range items {
		tagsJSON, _ := json.Marshal(item.Tags)
		metadataJSON, _ := json.Marshal(item.Metadata)

		_, err := stmt.ExecContext(ctx,
			item.ID,
			item.Name,
			item.Description,
			tagsJSON,
			metadataJSON,
			item.CreatedAt,
			item.UpdatedAt,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit()
}

// CleanAll removes all data from test tables
func (s *Seeder) CleanAll() error {
	tables := []string{"items"} // Add more tables as needed

	for _, table := range tables {
		_, err := s.db.Exec("DELETE FROM " + table)
		if err != nil {
			return err
		}
	}

	return nil
}

// SeedForE2E seeds comprehensive data for E2E tests
func (s *Seeder) SeedForE2E() error {
	if err := s.CleanAll(); err != nil {
		return err
	}

	// Seed items
	if err := s.SeedItems("test/fixtures/items/valid_items.json"); err != nil {
		return err
	}

	// Seed other entities as needed

	return nil
}
```

---

## 5. Frontend Test Data (React/TypeScript)

### 5.1. Static Fixtures

**File:** `src/__fixtures__/items.ts`

```typescript
import type { Item } from '../api/types';

export const validItems: Item[] = [
  {
    id: '550e8400-e29b-41d4-a716-446655440000',
    name: 'Valid Item 1',
    description: 'This is a valid item for testing',
    tags: ['test', 'valid'],
    metadata: {
      priority: 'high',
      category: 'testing',
    },
    created_at: '2025-10-23T10:00:00Z',
    updated_at: '2025-10-23T10:00:00Z',
  },
  {
    id: '550e8400-e29b-41d4-a716-446655440001',
    name: 'Valid Item 2',
    description: 'Another valid item',
    tags: ['test'],
    metadata: {},
    created_at: '2025-10-23T11:00:00Z',
    updated_at: '2025-10-23T11:00:00Z',
  },
];

export const itemWithLongName: Item = {
  id: '550e8400-e29b-41d4-a716-446655440020',
  name: 'a'.repeat(255),
  description: 'Edge case: maximum name length',
  tags: [],
  metadata: {},
  created_at: '2025-10-23T10:00:00Z',
  updated_at: '2025-10-23T10:00:00Z',
};

export const itemWithUnicode: Item = {
  id: '550e8400-e29b-41d4-a716-446655440022',
  name: 'Тестовый предмет 测试项目 🚀',
  description: 'Edge case: Unicode support',
  tags: ['unicode', 'тест', '测试'],
  metadata: {
    key: 'значение',
  },
  created_at: '2025-10-23T10:00:00Z',
  updated_at: '2025-10-23T10:00:00Z',
};

export const emptyItemsList: Item[] = [];
```

---

### 5.2. Test Data Factories (TypeScript)

**File:** `src/__fixtures__/factories.ts`

```typescript
import { faker } from '@faker-js/faker';
import type { Item, CreateItemInput } from '../api/types';

export class ItemFactory {
  private item: Partial<Item> = {};

  constructor() {
    this.item = {
      id: faker.string.uuid(),
      name: faker.commerce.productName(),
      description: faker.commerce.productDescription(),
      tags: [faker.word.sample(), faker.word.sample()],
      metadata: {},
      created_at: faker.date.past().toISOString(),
      updated_at: faker.date.recent().toISOString(),
    };
  }

  withId(id: string): this {
    this.item.id = id;
    return this;
  }

  withName(name: string): this {
    this.item.name = name;
    return this;
  }

  withDescription(description: string): this {
    this.item.description = description;
    return this;
  }

  withTags(...tags: string[]): this {
    this.item.tags = tags;
    return this;
  }

  withMetadata(metadata: Record<string, unknown>): this {
    this.item.metadata = metadata;
    return this;
  }

  build(): Item {
    return this.item as Item;
  }

  buildMany(count: number): Item[] {
    return Array.from({ length: count }, () => new ItemFactory().build());
  }
}

// Helper functions
export function createValidItem(overrides?: Partial<Item>): Item {
  return {
    ...new ItemFactory().build(),
    ...overrides,
  };
}

export function createItemsList(count: number): Item[] {
  return new ItemFactory().buildMany(count);
}

export function createItemInput(overrides?: Partial<CreateItemInput>): CreateItemInput {
  return {
    name: faker.commerce.productName(),
    description: faker.commerce.productDescription(),
    tags: [faker.word.sample()],
    metadata: {},
    ...overrides,
  };
}
```

**Пример использования:**

```typescript
import { ItemFactory, createValidItem } from '../__fixtures__/factories';

describe('ItemList', () => {
  test('renders items from factory', () => {
    const items = new ItemFactory().buildMany(5);
    render(<ItemList items={items} />);

    expect(screen.getAllByRole('listitem')).toHaveLength(5);
  });

  test('handles item with custom data', () => {
    const item = new ItemFactory()
      .withName('Custom Item')
      .withTags('custom', 'test')
      .build();

    render(<ItemList items={[item]} />);

    expect(screen.getByText('Custom Item')).toBeInTheDocument();
  });
});
```

---

### 5.3. MSW Handlers для API Mocking

**File:** `src/__mocks__/handlers.ts`

```typescript
import { rest } from 'msw';
import { validItems, emptyItemsList } from '../__fixtures__/items';
import type { Item, PaginatedResponse } from '../api/types';

const API_BASE_URL = '/api/v1';

export const handlers = [
  // GET /api/v1/items - Success
  rest.get(`${API_BASE_URL}/items`, (req, res, ctx) => {
    const page = Number(req.url.searchParams.get('page')) || 1;
    const limit = Number(req.url.searchParams.get('limit')) || 20;

    const response: PaginatedResponse<Item> = {
      data: validItems,
      pagination: {
        page,
        limit,
        total: validItems.length,
        total_pages: 1,
      },
    };

    return res(ctx.status(200), ctx.json(response));
  }),

  // GET /api/v1/items - Empty
  rest.get(`${API_BASE_URL}/items/empty`, (req, res, ctx) => {
    const response: PaginatedResponse<Item> = {
      data: emptyItemsList,
      pagination: {
        page: 1,
        limit: 20,
        total: 0,
        total_pages: 0,
      },
    };

    return res(ctx.status(200), ctx.json(response));
  }),

  // GET /api/v1/items/:id - Success
  rest.get(`${API_BASE_URL}/items/:id`, (req, res, ctx) => {
    const { id } = req.params;
    const item = validItems.find((i) => i.id === id);

    if (!item) {
      return res(
        ctx.status(404),
        ctx.json({
          error: {
            code: 'ITEM_NOT_FOUND',
            message: 'Item not found',
            request_id: 'mock-request-id',
          },
        })
      );
    }

    return res(ctx.status(200), ctx.json(item));
  }),

  // POST /api/v1/items - Success
  rest.post(`${API_BASE_URL}/items`, async (req, res, ctx) => {
    const input = await req.json();

    const newItem: Item = {
      id: faker.string.uuid(),
      ...input,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    return res(ctx.status(201), ctx.json(newItem));
  }),

  // POST /api/v1/items - Validation Error
  rest.post(`${API_BASE_URL}/items/validation-error`, async (req, res, ctx) => {
    return res(
      ctx.status(400),
      ctx.json({
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Invalid input data',
          details: [
            {
              field: 'name',
              issue: 'must not be empty',
            },
          ],
          request_id: 'mock-request-id',
        },
      })
    );
  }),

  // DELETE /api/v1/items/:id - Success
  rest.delete(`${API_BASE_URL}/items/:id`, (req, res, ctx) => {
    return res(ctx.status(204));
  }),

  // Network Error Simulation
  rest.get(`${API_BASE_URL}/items/network-error`, (req, res) => {
    return res.networkError('Failed to connect');
  }),
];
```

**File:** `src/setupTests.ts`

```typescript
import '@testing-library/jest-dom';
import { setupServer } from 'msw/node';
import { handlers } from './__mocks__/handlers';

// Setup MSW server
export const server = setupServer(...handlers);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

---

## 6. Test Data Best Practices

### 6.1. Принципы создания Test Data

1. **Используйте Factories для динамических данных:**
   ```go
   item := factories.NewItemFactory().WithName("Test").Build()
   ```

2. **Используйте Fixtures для статических сценариев:**
   ```go
   items, _ := fixtures.LoadValidItems()
   ```

3. **Изолируйте тестовые данные:**
   ```go
   func TestSomething(t *testing.T) {
       // Clean up after test
       defer cleanupTestData()

       // Create isolated test data
       item := factories.NewValidItem()
   }
   ```

4. **Используйте осмысленные имена:**
   ```go
   // Good
   validItem := factories.NewValidItem()
   itemWithMaxTags := factories.NewItemWithMaxTags()

   // Bad
   item1 := factories.NewItem()
   item2 := factories.NewItem()
   ```

5. **Документируйте edge cases в fixtures:**
   ```json
   {
     "comment": "Item with exactly 255 characters in name",
     "name": "..."
   }
   ```

### 6.2. Управление Test Data Lifecycle

**Setup:**
```go
func setupTestData(t *testing.T) (*sql.DB, func()) {
    db := setupTestDatabase(t)
    seeder := seed.NewSeeder(db)

    // Seed initial data
    seeder.SeedForE2E()

    // Return cleanup function
    cleanup := func() {
        seeder.CleanAll()
        db.Close()
    }

    return db, cleanup
}
```

**Usage:**
```go
func TestIntegration(t *testing.T) {
    db, cleanup := setupTestData(t)
    defer cleanup()

    // Test with seeded data
}
```

### 6.3. Test Data Versioning

- Fixtures хранятся в Git и версионируются
- Изменения в fixtures требуют code review
- Breaking changes в fixtures документируются в PR description

---

## 7. Performance Test Data

### 7.1. Large Dataset Generation

**File:** `test/performance/data_generator.go`

```go
package performance

import (
	"github.com/soft-yt/app-base-go-react/test/factories"
)

// GenerateLargeItemDataset creates N items for performance testing
func GenerateLargeItemDataset(count int) []models.Item {
	items := make([]models.Item, count)

	for i := 0; i < count; i++ {
		items[i] = factories.NewItemFactory().
			WithName(fmt.Sprintf("Performance Test Item %d", i)).
			Build()
	}

	return items
}

// BulkInsertItems inserts large dataset into database
func BulkInsertItems(db *sql.DB, items []models.Item) error {
	// Batch insert implementation
	const batchSize = 1000

	for i := 0; i < len(items); i += batchSize {
		end := i + batchSize
		if end > len(items) {
			end = len(items)
		}

		batch := items[i:end]
		if err := insertBatch(db, batch); err != nil {
			return err
		}
	}

	return nil
}
```

---

## 8. Security Test Data

### 8.1. Malicious Input Fixtures

**File:** `test/fixtures/security/malicious_inputs.json`

```json
[
  {
    "comment": "SQL Injection attempt",
    "name": "'; DROP TABLE items; --",
    "description": "SQL injection test",
    "expected_behavior": "Sanitized and stored safely"
  },
  {
    "comment": "XSS attempt",
    "name": "<script>alert('XSS')</script>",
    "description": "XSS test",
    "expected_behavior": "Script tags escaped or removed"
  },
  {
    "comment": "Path traversal",
    "name": "../../etc/passwd",
    "description": "Path traversal test",
    "expected_behavior": "Treated as regular string"
  },
  {
    "comment": "Command injection",
    "name": "; rm -rf /",
    "description": "Command injection test",
    "expected_behavior": "Sanitized"
  }
]
```

---

## 9. Связанные документы

- [Спецификация тестирования](testing-specification.md)
- [API-контракты](api-contracts.md)
- [Примеры референсной реализации](implementation-examples.md)
- [Definition of Done](definition-of-done.md)

---

## 10. Maintenance и обновление

### 10.1. Регулярные проверки

- Ежемесячно: проверка актуальности fixtures
- При изменении API: обновление соответствующих fixtures
- При добавлении новых entity: создание соответствующих factories

### 10.2. Ownership

- **Backend Test Data:** Backend team
- **Frontend Test Data:** Frontend team
- **Integration Test Data:** QA team
- **Performance Test Data:** Platform team
