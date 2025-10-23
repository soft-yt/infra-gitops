# Спецификация CI/CD конвейера

**Статус документа:** Draft · **Аудитория:** DevOps и платформа.

## 1. Обзор конвейера
- Триггер: push/PR в репозиториях, созданных из шаблона (`main`, feature-ветки) через GitHub Actions.
- Jobs: `backend` → `frontend` (frontend зависит от артефактов backend), оба запускаются на `ubuntu-latest`.
- Артефакты: контейнеры в GHCR (`ghcr.io/soft-yt/<service>-backend`, `...-frontend`).

## 2. Job backend
```yaml
jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go test ./...
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GHCR_PAT }}
      - uses: docker/build-push-action@v6
        with:
          context: backend
          file: backend/Dockerfile
          push: true
          tags: ghcr.io/soft-yt/<service>-backend:${{ github.sha }}
```

## 3. Job frontend
- Зависит от `backend`, чтобы переиспользовать checkout и логику обновления тега.
- Перед сборкой выполняет тесты (`npm ci && npm test -- --runInBand`).
- Собирает образ из корня с `frontend/Dockerfile` и публикует в GHCR.

## 4. Обновление GitOps
- После успешных job запускается `gitops-update` с PAT к `infra-gitops`.
- Шаги:
  1. Клонировать `infra-gitops`.
  2. Обновить теги образов в `apps/<service>/overlays/<env>/kustomization.yaml` (через `yq` или кастомный скрипт).
  3. Закоммитить `chore(gitops): bump <service> to ${{ github.sha }}` и открыть PR (либо пушить в auto-sync ветку).
- Конвейер должен быть идемпотентным и проходить через branch protection.

## 5. Релизная стратегия
- Тегировать релизы в сервисном репозитории (`vX.Y.Z`), чтобы триггерить промо-пайплайн (этап планируется).
- Опционально использовать GitHub Environments (`dev`, `staging`, `prod`) для ручных approval.

## 6. Секреты и безопасность
- Хранить `GHCR_PAT`, `INFRA_GITOPS_TOKEN`, `COSIGN_KEY` в GitHub Secrets; при необходимости привязывать к Environment.
- Настроить OIDC-федерацию для доступа к реестрам YC/Sber/VK без статических ключей.
- Подписывать контейнеры через Cosign и проверять подписи через Argo CD ImagePolicy.

## 7. Открытые вопросы
- Авто-merge GitOps PR или обязательный review?
- Минимальная матрица тестов (версии Go, Node) для шаблонных репозиториев.
- Механизм промоушена релизов (GitHub Environments против Argo Image Updater).
