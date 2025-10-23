# Шаблон сервиса: app-base-go-react

**Статус документа:** Draft · **Область:** монорепозиторий для сервисов с Go backend и React frontend.

## 1. Структура репозитория
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
├── deploy/kustomize/apps/webapp/
│   ├── base/                  # Общие Deployment + Service
│   └── overlays/dev/          # Настройки окружения (реплики, ingress и т.д.)
├── .github/workflows/ci.yml
└── docker-compose.yml         # Локальный интеграционный запуск
```

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

## 4. Манифесты деплоя
- База Kustomize разворачивает один Pod с двумя контейнерами (`backend`, `frontend`).
- Overlays накладывают окруженческие настройки: теги образов, реплики, ingress-хосты, сайдкары Vault.
- Service экспортирует HTTP на порт 80; ingress/gateway добавляются patch-ами overlay.

## 5. Точки расширения
- Новые overlays размещаются в `deploy/kustomize/apps/webapp/overlays/<env>/` по образцу `dev`.
- Фоновые воркеры добавляются отдельным Deployment в base; не забыть включить сборку нового образа в CI.
- Фичи-флаги выносятся в ConfigMap/Secret; предпочтительно держать шаблоны в SOPS-шифрованном YAML.

## 6. Открытые вопросы
- Выбрать библиотеки логирования/метрик по умолчанию для Go и React.
- Уточнить каркас API backend (REST или gRPC + HTTP gateway).
- Подготовить примеры интеграционных тестов (compose + smoke) для команд, наследующих шаблон.
