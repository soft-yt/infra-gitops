# Плейбук локальной разработки

**Статус документа:** Draft · **Аудитория:** разработчики сервисов.

## 1. Предпосылки
- Docker Desktop или Colima в качестве контейнерного рантайма.
- Go 1.22+, Node.js 20+, пакетный менеджер pnpm или npm (стандарт уточняется).
- mkcert (опционально) для локального TLS при тестировании ingress.

## 2. Создание сервиса
1. Сгенерировать репозиторий через Backstage или CLI (`x5 service create --template go-react --name myapp`).
2. Заменить плейсхолдеры (`myapp`) по проекту и обновить метаданные.
3. Выполнить `make -C backend deps` и `npm install --prefix frontend` для установки зависимостей.

## 3. Режимы запуска
- **Compose:** `docker-compose up` поднимает backend (8080) + frontend (5173) с hot reload.
- **Раздельно:**
  - `make -C backend run` — Go API с live reload (рекомендуется air/CompileDaemon).
  - `npm run dev --prefix frontend` — Vite сервер с прокси `/api`.
- **Kind/k3d:** применять `deploy/kustomize/apps/webapp/overlays/dev` и открыть сервис через ingress (`dev.localhost`).

## 4. Тесты и проверки
- Backend: `make -C backend test` (`go test ./...`).
- Frontend: `npm run test --prefix frontend`, `npm run lint` при наличии ESLint.
- Интеграционные (опционально): `npm run e2e` (Playwright) и `make -C backend smoke` (планируется).

## 5. Конфиги и секреты
- Локальные переменные хранить в `.env.local`, не коммитить.
- Общие конфиги добавлять как шаблоны в `deploy/kustomize/apps/webapp/base/configmap.yaml` с плейсхолдерами.
- В документации использовать фиктивные токены (`<TOKEN>`); реальные значения описывать в базе знаний Vault.

## 6. Траблшутинг
- Контейнеры не стартуют → очистить BuildKit кэш: `docker compose build --no-cache`.
- 404 с frontend → проверить прокси Vite и порт backend (8080).
- Argo CD не синхронизирует локально → убедиться в корректном `kubectl config current-context` и валидных токенах Argo CD.

## 7. Открытые вопросы
- Унифицировать команды lint/test (Makefile vs. npm scripts).
- Подготовить примерные датасеты/фикстуры для smoke-тестов.
- Рекомендовать базовый VS Code devcontainer.
