# API-контракты и спецификации

**Статус документа:** Draft · **Аудитория:** разработчики backend/frontend, QA.

## 1. Обзор

Документ определяет API-контракты для шаблона `app-base-go-react` и служит основой для Test-Driven Development. Все endpoint'ы должны быть описаны ДО реализации, чтобы frontend и backend команды могли работать параллельно.

## 2. Общие принципы API

### 2.1. Базовые требования
- **Protocol:** HTTP/1.1, REST-подобный стиль
- **Base Path:** `/api/v1`
- **Content-Type:** `application/json` для запросов и ответов
- **Encoding:** UTF-8
- **Authentication:** Bearer token в заголовке `Authorization` (опционально для базового шаблона)
- **CORS:** Настраивается через middleware, разрешены запросы с frontend origin

### 2.2. Общие HTTP коды ответов
- `200 OK` — успешная операция
- `201 Created` — ресурс создан
- `204 No Content` — успешная операция без тела ответа
- `400 Bad Request` — невалидные входные данные
- `401 Unauthorized` — отсутствует или невалидна аутентификация
- `403 Forbidden` — недостаточно прав
- `404 Not Found` — ресурс не найден
- `409 Conflict` — конфликт состояния (например, дубликат)
- `422 Unprocessable Entity` — ошибки валидации бизнес-логики
- `500 Internal Server Error` — внутренняя ошибка сервера
- `503 Service Unavailable` — сервис временно недоступен

### 2.3. Стандартный формат ошибки

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "email",
        "issue": "must be a valid email address"
      }
    ],
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

**Поля:**
- `code` (string, обязательно) — машиночитаемый код ошибки
- `message` (string, обязательно) — человекочитаемое описание
- `details` (array, опционально) — детальная информация об ошибках валидации
- `request_id` (string, обязательно) — UUID запроса для трейсинга

### 2.4. Pagination

Для endpoint'ов с множественными результатами:

**Query параметры:**
- `page` (integer, default: 1) — номер страницы
- `limit` (integer, default: 20, max: 100) — количество элементов на странице

**Формат ответа:**
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "total_pages": 5
  }
}
```

---

## 3. Health Check API

### 3.1. GET /healthz

**Назначение:** Проверка живости сервиса (liveness probe).

**Запрос:**
```http
GET /healthz HTTP/1.1
Host: api.example.com
```

**Успешный ответ (200 OK):**
```json
{
  "status": "healthy",
  "timestamp": "2025-10-23T10:30:00Z"
}
```

**Ошибочный ответ (503 Service Unavailable):**
```json
{
  "status": "unhealthy",
  "timestamp": "2025-10-23T10:30:00Z"
}
```

**Acceptance Criteria:**
- AC-001: Endpoint отвечает за <100ms при нормальной работе
- AC-002: Возвращает 200, если все зависимости доступны
- AC-003: Возвращает 503, если критические зависимости недоступны
- AC-004: Не требует аутентификации

---

### 3.2. GET /readyz

**Назначение:** Проверка готовности к обработке запросов (readiness probe).

**Запрос:**
```http
GET /readyz HTTP/1.1
Host: api.example.com
```

**Успешный ответ (200 OK):**
```json
{
  "status": "ready",
  "checks": {
    "database": "ok",
    "cache": "ok",
    "vault": "ok"
  },
  "timestamp": "2025-10-23T10:30:00Z"
}
```

**Ошибочный ответ (503 Service Unavailable):**
```json
{
  "status": "not_ready",
  "checks": {
    "database": "ok",
    "cache": "failed",
    "vault": "ok"
  },
  "timestamp": "2025-10-23T10:30:00Z"
}
```

**Acceptance Criteria:**
- AC-005: Проверяет подключение ко всем критическим зависимостям
- AC-006: Возвращает 200 только если все проверки успешны
- AC-007: Детализирует статус каждой зависимости
- AC-008: Таймаут на проверку зависимостей не более 5 секунд

---

### 3.3. GET /metrics

**Назначение:** Экспорт метрик для Prometheus.

**Запрос:**
```http
GET /metrics HTTP/1.1
Host: api.example.com
```

**Успешный ответ (200 OK):**
```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/v1/items",status="200"} 1234

# HELP http_request_duration_seconds HTTP request latency
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 1000
http_request_duration_seconds_bucket{le="0.5"} 1200
http_request_duration_seconds_sum 300
http_request_duration_seconds_count 1234
```

**Acceptance Criteria:**
- AC-009: Формат Prometheus text exposition format
- AC-010: Включает стандартные метрики (requests, latency, errors)
- AC-011: Endpoint доступен без аутентификации (защищается на уровне ingress)

---

## 4. Базовое CRUD API (пример для "Items")

### 4.1. POST /api/v1/items

**Назначение:** Создание нового item.

**Запрос:**
```http
POST /api/v1/items HTTP/1.1
Host: api.example.com
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "Sample Item",
  "description": "Description of the item",
  "tags": ["tag1", "tag2"],
  "metadata": {
    "key1": "value1"
  }
}
```

**Успешный ответ (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Sample Item",
  "description": "Description of the item",
  "tags": ["tag1", "tag2"],
  "metadata": {
    "key1": "value1"
  },
  "created_at": "2025-10-23T10:30:00Z",
  "updated_at": "2025-10-23T10:30:00Z"
}
```

**Ошибочный ответ (400 Bad Request):**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid input data",
    "details": [
      {
        "field": "name",
        "issue": "must not be empty"
      }
    ],
    "request_id": "660e8400-e29b-41d4-a716-446655440001"
  }
}
```

**Validation Rules:**
- `name` (string, обязательно): 1-255 символов
- `description` (string, опционально): 0-2000 символов
- `tags` (array of strings, опционально): максимум 10 тегов, каждый 1-50 символов
- `metadata` (object, опционально): произвольный JSON объект, максимум 10KB

**Acceptance Criteria:**
- AC-012: Item создается с уникальным UUID
- AC-013: Возвращает 201 с полными данными item включая timestamps
- AC-014: Валидирует все обязательные поля
- AC-015: Возвращает 400 с детальным описанием ошибок валидации
- AC-016: Требует валидный Bearer token
- AC-017: Устанавливает `created_at` и `updated_at` в момент создания

---

### 4.2. GET /api/v1/items

**Назначение:** Получение списка items с пагинацией и фильтрацией.

**Запрос:**
```http
GET /api/v1/items?page=1&limit=20&tags=tag1&search=sample HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
```

**Query параметры:**
- `page` (integer, опционально, default: 1) — номер страницы
- `limit` (integer, опционально, default: 20, max: 100) — количество на странице
- `tags` (string, опционально) — фильтр по тегам (comma-separated)
- `search` (string, опционально) — поиск по name и description
- `sort` (string, опционально, default: "created_at") — поле сортировки
- `order` (string, опционально, default: "desc") — направление сортировки (asc/desc)

**Успешный ответ (200 OK):**
```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Sample Item",
      "description": "Description",
      "tags": ["tag1"],
      "metadata": {},
      "created_at": "2025-10-23T10:30:00Z",
      "updated_at": "2025-10-23T10:30:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 1,
    "total_pages": 1
  }
}
```

**Acceptance Criteria:**
- AC-018: Возвращает пустой массив если items не найдены (не 404)
- AC-019: Пагинация работает корректно с валидацией page/limit
- AC-020: Фильтр по тегам работает как AND (все указанные теги должны присутствовать)
- AC-021: Поиск выполняется case-insensitive по name и description
- AC-022: Сортировка работает по указанному полю и направлению
- AC-023: Возвращает 400 при невалидных параметрах (limit > 100)

---

### 4.3. GET /api/v1/items/{id}

**Назначение:** Получение одного item по ID.

**Запрос:**
```http
GET /api/v1/items/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
```

**Успешный ответ (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Sample Item",
  "description": "Description of the item",
  "tags": ["tag1", "tag2"],
  "metadata": {
    "key1": "value1"
  },
  "created_at": "2025-10-23T10:30:00Z",
  "updated_at": "2025-10-23T10:30:00Z"
}
```

**Ошибочный ответ (404 Not Found):**
```json
{
  "error": {
    "code": "ITEM_NOT_FOUND",
    "message": "Item with specified ID not found",
    "request_id": "660e8400-e29b-41d4-a716-446655440001"
  }
}
```

**Acceptance Criteria:**
- AC-024: Возвращает полные данные item если существует
- AC-025: Возвращает 404 если item не найден
- AC-026: Возвращает 400 если ID невалидный UUID

---

### 4.4. PUT /api/v1/items/{id}

**Назначение:** Полное обновление item.

**Запрос:**
```http
PUT /api/v1/items/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.example.com
Content-Type: application/json
Authorization: Bearer <token>

{
  "name": "Updated Item",
  "description": "Updated description",
  "tags": ["tag2", "tag3"],
  "metadata": {
    "key2": "value2"
  }
}
```

**Успешный ответ (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Updated Item",
  "description": "Updated description",
  "tags": ["tag2", "tag3"],
  "metadata": {
    "key2": "value2"
  },
  "created_at": "2025-10-23T10:30:00Z",
  "updated_at": "2025-10-23T11:00:00Z"
}
```

**Acceptance Criteria:**
- AC-027: Полностью заменяет все поля item
- AC-028: Обновляет `updated_at` timestamp
- AC-029: Сохраняет `created_at` без изменений
- AC-030: Возвращает 404 если item не найден
- AC-031: Применяет те же правила валидации что и POST

---

### 4.5. PATCH /api/v1/items/{id}

**Назначение:** Частичное обновление item.

**Запрос:**
```http
PATCH /api/v1/items/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.example.com
Content-Type: application/json
Authorization: Bearer <token>

{
  "description": "Partially updated description"
}
```

**Успешный ответ (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Updated Item",
  "description": "Partially updated description",
  "tags": ["tag2", "tag3"],
  "metadata": {
    "key2": "value2"
  },
  "created_at": "2025-10-23T10:30:00Z",
  "updated_at": "2025-10-23T11:15:00Z"
}
```

**Acceptance Criteria:**
- AC-032: Обновляет только указанные поля
- AC-033: Не затрагивает неуказанные поля
- AC-034: Обновляет `updated_at` timestamp
- AC-035: Возвращает 404 если item не найден

---

### 4.6. DELETE /api/v1/items/{id}

**Назначение:** Удаление item.

**Запрос:**
```http
DELETE /api/v1/items/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: api.example.com
Authorization: Bearer <token>
```

**Успешный ответ (204 No Content):**
```
(пустое тело)
```

**Ошибочный ответ (404 Not Found):**
```json
{
  "error": {
    "code": "ITEM_NOT_FOUND",
    "message": "Item with specified ID not found",
    "request_id": "660e8400-e29b-41d4-a716-446655440001"
  }
}
```

**Acceptance Criteria:**
- AC-036: Удаляет item если он существует
- AC-037: Возвращает 204 без тела ответа при успехе
- AC-038: Возвращает 404 если item не найден
- AC-039: Повторное удаление того же item возвращает 404
- AC-040: Soft delete (опционально) — item помечается как deleted, но не удаляется физически

---

## 5. Frontend-Backend взаимодействие

### 5.1. Environment Configuration API

**GET /api/v1/config**

**Назначение:** Получение клиентской конфигурации для frontend.

**Запрос:**
```http
GET /api/v1/config HTTP/1.1
Host: api.example.com
```

**Успешный ответ (200 OK):**
```json
{
  "app_name": "Soft-YT Platform",
  "version": "1.0.0",
  "environment": "development",
  "features": {
    "auth_enabled": false,
    "dark_mode": true,
    "analytics": false
  },
  "api_base_url": "/api/v1"
}
```

**Acceptance Criteria:**
- AC-041: Возвращает публичную конфигурацию без секретов
- AC-042: Не требует аутентификации
- AC-043: Кешируется на 5 минут

---

## 6. Error Codes Reference

| Код | HTTP Status | Описание |
|-----|-------------|----------|
| `VALIDATION_ERROR` | 400 | Ошибки валидации входных данных |
| `UNAUTHORIZED` | 401 | Отсутствует или невалидна аутентификация |
| `FORBIDDEN` | 403 | Недостаточно прав для операции |
| `ITEM_NOT_FOUND` | 404 | Запрошенный item не найден |
| `CONFLICT` | 409 | Конфликт состояния (дубликат) |
| `UNPROCESSABLE_ENTITY` | 422 | Ошибка бизнес-логики |
| `INTERNAL_ERROR` | 500 | Внутренняя ошибка сервера |
| `SERVICE_UNAVAILABLE` | 503 | Сервис временно недоступен |
| `RATE_LIMIT_EXCEEDED` | 429 | Превышен лимит запросов |

---

## 7. Non-Functional Requirements

### 7.1. Performance
- **Response Time:** p95 < 200ms для GET запросов
- **Response Time:** p95 < 500ms для POST/PUT/PATCH запросов
- **Throughput:** минимум 100 RPS на одном инстансе

### 7.2. Security
- **TLS:** Все API доступны только через HTTPS в продакшене
- **Rate Limiting:** 100 запросов/минуту на IP для неаутентифицированных запросов
- **Rate Limiting:** 1000 запросов/минуту для аутентифицированных пользователей
- **Input Sanitization:** Все входные данные должны быть очищены от потенциально опасного содержимого

### 7.3. Logging & Tracing
- Каждый запрос логируется с уровнем INFO (method, path, status, duration)
- Ошибки логируются с уровнем ERROR включая stack trace
- Request ID передается в заголовке `X-Request-ID` и включается в логи
- OpenTelemetry spans для всех endpoint'ов

### 7.4. Versioning
- API версионируется через URL path (`/api/v1`, `/api/v2`)
- Backward compatibility сохраняется в рамках мажорной версии
- Deprecated endpoint'ы помечаются заголовком `Deprecation` за 6 месяцев до удаления

---

## 8. OpenAPI Specification

Полная спецификация в формате OpenAPI 3.0 должна быть сгенерирована и доступна по адресу:

```
GET /api/v1/openapi.json
GET /api/v1/docs (Swagger UI)
```

**Acceptance Criteria:**
- AC-044: OpenAPI спецификация генерируется автоматически из кода
- AC-045: Swagger UI доступен в dev/staging окружениях
- AC-046: Swagger UI отключен в production окружении

---

## 9. Открытые вопросы

- Нужна ли аутентификация для базового шаблона или она добавляется опционально?
- Какую библиотеку использовать для генерации OpenAPI спецификации из Go кода?
- Требуется ли GraphQL endpoint в дополнение к REST?
- Нужна ли поддержка WebSocket для real-time обновлений?
- Как реализовать versioning API при breaking changes?

---

## 10. Связанные документы

- [Спецификация тестирования](testing-specification.md) — тестовые сценарии для API
- [Шаблон сервиса](service-template-app-base-go-react.md) — структура backend
- [Примеры реализации](implementation-examples.md) — референсный код
