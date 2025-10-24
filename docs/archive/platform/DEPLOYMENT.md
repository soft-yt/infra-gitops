# Deployment Guide

Руководство по развертыванию приложения App Base Go React.

## Содержание

1. [Локальная разработка](#локальная-разработка)
2. [Docker Compose](#docker-compose)
3. [Kubernetes](#kubernetes)
4. [CI/CD](#cicd)
5. [Мониторинг](#мониторинг)

---

## Локальная разработка

### Предварительные требования

- Go 1.22+
- Node.js 20+
- Docker Desktop (для контейнеров)

### Backend

```bash
cd backend

# Установить зависимости
go mod download

# Запустить сервер
go run cmd/api/main.go

# Или использовать Makefile
make run
```

Backend будет доступен на http://localhost:8080

### Frontend

```bash
cd frontend

# Установить зависимости
npm install

# Запустить dev сервер
npm run dev
```

Frontend будет доступен на http://localhost:5173

API запросы будут проксироваться на backend через Vite proxy.

---

## Docker Compose

### Запуск всех сервисов

```bash
# Скопировать example env файл
cp .env.example .env

# Запустить все сервисы
docker-compose up

# В detached mode
docker-compose up -d

# Пересобрать образы
docker-compose up --build

# Остановить и удалить контейнеры
docker-compose down

# Удалить volumes
docker-compose down -v
```

### Проверка статуса

```bash
# Список запущенных контейнеров
docker-compose ps

# Логи всех сервисов
docker-compose logs

# Логи конкретного сервиса
docker-compose logs backend
docker-compose logs frontend

# Следить за логами в реальном времени
docker-compose logs -f
```

### Доступ к сервисам

- Frontend: http://localhost:5173
- Backend API: http://localhost:8080
- Health Check: http://localhost:8080/healthz

---

## Kubernetes

### Предварительные требования

- kubectl
- Kubernetes cluster (minikube, kind, k3d, или облачный)
- kustomize (опционально, встроен в kubectl 1.14+)

### Настройка контекста

```bash
# Проверить текущий контекст
kubectl config current-context

# Список всех контекстов
kubectl config get-contexts

# Переключиться на нужный контекст
kubectl config use-context <context-name>
```

### Развертывание с Kustomize

#### Base (минимальная конфигурация)

```bash
# Просмотр манифестов
kubectl kustomize deploy/kustomize/apps/webapp/base

# Применить
kubectl apply -k deploy/kustomize/apps/webapp/base

# Проверить статус
kubectl get pods -l app=webapp
kubectl get svc webapp
```

#### Dev Overlay

```bash
# Просмотр манифестов с overlay
kubectl kustomize deploy/kustomize/apps/webapp/overlays/dev

# Применить dev конфигурацию
kubectl apply -k deploy/kustomize/apps/webapp/overlays/dev

# Проверить в namespace dev
kubectl get pods -n dev -l app=webapp
```

### Проверка развертывания

```bash
# Статус pods
kubectl get pods -l app=webapp

# Детальная информация
kubectl describe pod <pod-name>

# Логи backend контейнера
kubectl logs <pod-name> -c backend

# Логи frontend контейнера
kubectl logs <pod-name> -c frontend

# Следить за логами
kubectl logs -f <pod-name> -c backend

# Все логи приложения
kubectl logs -l app=webapp --all-containers
```

### Port Forwarding

```bash
# Прокинуть frontend
kubectl port-forward svc/webapp 8080:80

# Прокинуть backend напрямую
kubectl port-forward svc/backend 8080:8080

# Прокинуть конкретный pod
kubectl port-forward <pod-name> 8080:80
```

Приложение будет доступно на http://localhost:8080

### Scaling

```bash
# Масштабировать deployment
kubectl scale deployment webapp --replicas=3

# Проверить количество реплик
kubectl get deployment webapp

# Автомасштабирование (HPA)
kubectl autoscale deployment webapp --min=2 --max=10 --cpu-percent=80
```

### Обновление образов

```bash
# Обновить image tag
kubectl set image deployment/webapp \
  backend=ghcr.io/soft-yt/app-base-go-react-backend:v1.2.3 \
  frontend=ghcr.io/soft-yt/app-base-go-react-frontend:v1.2.3

# Проверить статус rollout
kubectl rollout status deployment/webapp

# История rollout
kubectl rollout history deployment/webapp

# Откатиться к предыдущей версии
kubectl rollout undo deployment/webapp

# Откатиться к конкретной ревизии
kubectl rollout undo deployment/webapp --to-revision=2
```

### Удаление

```bash
# Удалить deployment
kubectl delete -k deploy/kustomize/apps/webapp/base

# Удалить из конкретного namespace
kubectl delete -k deploy/kustomize/apps/webapp/overlays/dev

# Форсированное удаление
kubectl delete pod <pod-name> --force --grace-period=0
```

---

## CI/CD

### GitHub Actions

Проект использует GitHub Actions для автоматической сборки и деплоя.

#### Workflow триггеры

- Push в `main`, `master`, `develop` ветки
- Pull Request в эти ветки

#### Jobs

1. **backend-test**: Тесты Go, проверка coverage
2. **frontend-test**: Тесты React, линтеры, type check
3. **backend-build**: Сборка и публикация Docker образа
4. **frontend-build**: Сборка и публикация Docker образа
5. **gitops-update** (опционально): Обновление GitOps репозитория

#### Настройка секретов

В настройках GitHub репозитория (Settings → Secrets and variables → Actions):

- `GITHUB_TOKEN` - автоматически предоставляется
- `GITOPS_TOKEN` - Personal Access Token для обновления infra-gitops (опционально)

#### Проверка статуса

1. Перейти на вкладку "Actions" в GitHub
2. Выбрать workflow run
3. Проверить статус каждого job
4. Посмотреть логи при необходимости

#### Локальный запуск Actions

Использовать [act](https://github.com/nektos/act):

```bash
# Установить act
brew install act

# Запустить workflow локально
act push

# Запустить конкретный job
act -j backend-test

# С секретами
act push --secret-file .secrets
```

---

## Мониторинг

### Health Checks

#### Liveness Probe

Проверяет что приложение живо:

```bash
curl http://localhost:8080/healthz
```

Ответ:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-23T10:30:00Z"
}
```

#### Readiness Probe

Проверяет готовность к обработке запросов:

```bash
curl http://localhost:8080/readyz
```

Ответ:
```json
{
  "status": "ready",
  "checks": {
    "server": "ok"
  },
  "timestamp": "2025-10-23T10:30:00Z"
}
```

### Prometheus Metrics

```bash
curl http://localhost:8080/metrics
```

### Логи

#### Docker Compose

```bash
# Все логи
docker-compose logs

# Конкретный сервис
docker-compose logs backend
docker-compose logs frontend

# Следить за логами
docker-compose logs -f backend
```

#### Kubernetes

```bash
# Логи pod
kubectl logs <pod-name> -c backend
kubectl logs <pod-name> -c frontend

# Все логи приложения
kubectl logs -l app=webapp --all-containers

# Следить за логами
kubectl logs -f <pod-name> -c backend

# Предыдущий контейнер (после рестарта)
kubectl logs <pod-name> -c backend --previous
```

### Debugging

#### Exec в контейнер

Docker Compose:
```bash
docker-compose exec backend sh
docker-compose exec frontend sh
```

Kubernetes:
```bash
kubectl exec -it <pod-name> -c backend -- sh
kubectl exec -it <pod-name> -c frontend -- sh
```

#### Port forwarding для debugging

```bash
# Backend
kubectl port-forward <pod-name> 8080:8080

# Frontend
kubectl port-forward <pod-name> 8081:80
```

---

## Troubleshooting

### Backend проблемы

#### Порт занят

```bash
# Найти процесс на порту 8080
lsof -i :8080

# Убить процесс
kill -9 <PID>
```

#### Проблемы с зависимостями

```bash
cd backend
go mod tidy
go mod download
```

#### Тесты падают

```bash
# Очистить кэш
go clean -testcache

# Запустить с verbose
go test -v ./...
```

### Frontend проблемы

#### Node modules проблемы

```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

#### Proxy не работает

Проверить `vite.config.ts`:
```typescript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:8080',
      changeOrigin: true,
    },
  },
}
```

### Docker проблемы

#### Образы не обновляются

```bash
# Пересобрать без кэша
docker-compose build --no-cache

# Удалить старые образы
docker image prune -a
```

#### Volumes проблемы

```bash
# Удалить все volumes
docker-compose down -v

# Удалить конкретный volume
docker volume rm <volume-name>
```

### Kubernetes проблемы

#### Pod не запускается

```bash
# Проверить статус
kubectl describe pod <pod-name>

# Проверить events
kubectl get events --sort-by=.metadata.creationTimestamp

# Проверить логи
kubectl logs <pod-name> -c backend
```

#### ImagePullBackOff

```bash
# Проверить образ существует
docker pull ghcr.io/soft-yt/app-base-go-react-backend:latest

# Проверить credentials
kubectl get secret <imagePullSecret> -o yaml
```

#### CrashLoopBackOff

```bash
# Логи текущего контейнера
kubectl logs <pod-name> -c backend

# Логи предыдущего контейнера
kubectl logs <pod-name> -c backend --previous

# Exec в контейнер (если запускается)
kubectl exec -it <pod-name> -c backend -- sh
```

---

## Best Practices

### Безопасность

1. Не коммитить секреты в git
2. Использовать `.env.example` для примеров
3. Настроить RBAC в Kubernetes
4. Использовать Network Policies
5. Регулярно обновлять зависимости

### Performance

1. Настроить resource requests/limits
2. Использовать HPA для автомасштабирования
3. Настроить caching (Redis)
4. Оптимизировать Docker образы (multi-stage builds)

### Reliability

1. Настроить proper health checks
2. Использовать readiness probes
3. Настроить graceful shutdown
4. Использовать PodDisruptionBudget
5. Настроить мониторинг и алерты

### Observability

1. Структурированное логирование
2. Prometheus метрики
3. Distributed tracing (OpenTelemetry)
4. Centralized logging (ELK, Loki)
5. Dashboards (Grafana)

---

## Связанные документы

- [README.md](README.md) - Основная документация
- [Backend README](backend/README.md) - Backend документация
- [Frontend README](frontend/README.md) - Frontend документация
- [API Контракты](/docs/api-contracts.md)
- [Локальная разработка](/docs/local-development.md)
