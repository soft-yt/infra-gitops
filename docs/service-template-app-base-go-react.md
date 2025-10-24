# Шаблон сервиса: app-base-go-react

**Статус документа:** Active · **Область:** GitHub Template для создания сервисов с Go backend и React frontend.

## Обзор

`app-base-go-react` — это GitHub Template репозиторий для быстрого создания новых сервисов на стеке Go + React.

- **Репозиторий:** https://github.com/soft-yt/app-base-go-react
- **Тип:** GitHub Template (не монорепозиторий)
- **Назначение:** Быстрый старт новых микросервисов с готовым CI/CD

## Как использовать template

### Создание нового сервиса

1. **Через GitHub UI:**
   - Перейти на https://github.com/soft-yt/app-base-go-react
   - Нажать "Use this template" → "Create a new repository"
   - Указать название нового репозитория (например, `user-service`)
   - Создать репозиторий

2. **Через GitHub CLI:**
   ```bash
   gh repo create soft-yt/user-service --template soft-yt/app-base-go-react --private
   ```

3. **Настроить новый сервис:**
   - Клонировать созданный репозиторий
   - Обновить названия в `backend/go.mod`, `frontend/package.json`
   - Настроить GitHub Secrets: `GHCR_PAT`, `INFRA_GITOPS_TOKEN`
   - Создать соответствующие манифесты в `infra-gitops` репозитории

## 1. Структура template репозитория
```
app-base-go-react/
├── backend/
│   ├── cmd/api/main.go        # Точка входа, инициализация роутера и конфигурации
│   ├── internal/config/       # Загрузка и валидация настроек
│   ├── internal/http/         # Обработчики chi, middleware, маршрутизация
│   ├── go.mod                 # Зависимости Go
│   ├── Dockerfile
│   └── Makefile               # Утилиты для локальной разработки (run/test/lint)
├── frontend/
│   ├── src/App.tsx            # Основная композиция UI
│   ├── src/main.tsx           # Bootstrap и входная точка Vite
│   ├── package.json           # Скрипты и зависимости
│   ├── vite.config.ts         # Конфигурация dev/build с прокси на `/api`
│   ├── Dockerfile
│   └── README.md (опционально) # Документация фич команды
├── .github/workflows/ci.yml   # CI/CD pipeline
├── docker-compose.yml         # Локальный интеграционный запуск
└── TEMPLATE-README.md         # Инструкции по использованию
```

**Важно:** Деплой-манифесты НЕ находятся в этом репозитории. Они размещаются в отдельном репозитории `infra-gitops`.

## 2. Стандарты backend
- Порт `8080`, health-check `/healthz`, JSON-логирование со структурированными полями.
- Конфигурация из переменных окружения + `.env` (для dev). В `backend/README.md` фиксировать обязательные переменные.
- Управление зависимостями через Go Modules; фиксировать версии, выполнять `go fmt` перед коммитом.
- Юнит-тесты в `backend/internal/.../_test.go`; интеграционные планируются в `backend/test/`.

## 3. Стандарты frontend
- Vite dev server на порту `5173`, проксирует `/api` на backend-контейнер при локальной работе.
- TypeScript, React hooks, состояние через Zustand/React Query (нужно подтвердить командой).
- Тестирование: Vitest + Testing Library; snapshot-тесты допустимы только для layout-компонентов.
- Продакшн-сборка отдаётся Nginx (multi-stage Dockerfile) на порту `80`.

## 4. CI/CD Pipeline

Template включает готовый GitHub Actions workflow (`.github/workflows/ci.yml`):

- **Триггер:** Push в `main` или создание PR
- **Jobs:**
  - `backend`: тесты Go → сборка Docker → push в GHCR
  - `frontend`: тесты npm → сборка Docker → push в GHCR
  - `gitops-update`: обновление тегов в `infra-gitops` репозитории

Подробнее см. [ci-cd-pipeline.md](ci-cd-pipeline.md)

## 5. Деплой манифесты

Kubernetes манифесты НЕ находятся в сервисном репозитории. Они создаются в репозитории `infra-gitops`:

```
infra-gitops/
└── apps/
    └── <service-name>/
        ├── base/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── kustomization.yaml
        └── overlays/
            ├── dev/
            ├── staging/
            └── prod/
```

### Создание деплой манифестов для нового сервиса

После создания сервиса из template необходимо:

1. Создать директорию в `infra-gitops/apps/<service-name>/`
2. Добавить base манифесты (Deployment, Service)
3. Создать overlays для нужных окружений
4. Настроить Argo CD ApplicationSet для автодеплоя

Подробнее см. [gitops-operations.md](gitops-operations.md)

## 6. Точки расширения
- Новые окружения добавляются как overlays в `infra-gitops/apps/<service>/overlays/<env>/`
- Фоновые воркеры добавляются отдельным Deployment в base; включить сборку образа в CI
- Фичи-флаги выносятся в ConfigMap/Secret в `infra-gitops`; шифровать через SOPS

## 7. Открытые вопросы
- Выбрать библиотеки логирования/метрик по умолчанию для Go и React.
- Уточнить каркас API backend (REST или gRPC + HTTP gateway).
- Подготовить примеры интеграционных тестов (compose + smoke) для команд, использующих template.
- Автоматизировать создание структуры в `infra-gitops` при создании нового сервиса.
