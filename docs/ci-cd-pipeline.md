# Спецификация CI/CD конвейера

**Статус документа:** Active · **Аудитория:** DevOps и платформа.

## 1. Обзор конвейера

CI/CD pipeline находится в template репозитории `app-base-go-react` и наследуется всеми сервисами, созданными из него.

- **Расположение:** `.github/workflows/ci.yml` в каждом сервисном репозитории
- **Триггер:** Push в `main` или создание PR
- **Jobs:** `backend`, `frontend`, `gitops-update` (выполняются на `ubuntu-latest`)
- **Артефакты:** Docker образы в GHCR (`ghcr.io/soft-yt/<service>-backend`, `ghcr.io/soft-yt/<service>-frontend`)
- **GitOps интеграция:** Автоматическое обновление манифестов в `infra-gitops` репозитории

## 1.1. Поток развертывания

```
[Сервисный репозиторий]
    ↓ git push
[GitHub Actions CI]
    ├─→ Job: backend
    │   ├─ go test
    │   ├─ docker build
    │   └─ docker push → GHCR
    │
    ├─→ Job: frontend
    │   ├─ npm test
    │   ├─ docker build
    │   └─ docker push → GHCR
    │
    └─→ Job: gitops-update
        ├─ git clone infra-gitops
        ├─ yq update image tags
        ├─ git commit
        └─ create PR → infra-gitops
            ↓
    [infra-gitops PR review]
            ↓ merge
    [Argo CD auto-sync]
            ↓
    [Target Clusters: YC/VK/OnPrem]
```

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
- Выполняется параллельно с `backend` (независимые jobs).
- Перед сборкой выполняет тесты (`npm ci && npm test -- --runInBand`).
- Собирает образ из корня с `frontend/Dockerfile` и публикует в GHCR.
- Использует тот же механизм тегирования: `${{ github.sha }}`.

## 4. Job gitops-update

Этот job обновляет манифесты в репозитории `infra-gitops` после успешной сборки образов.

### 4.1. Зависимости
```yaml
gitops-update:
  needs: [backend, frontend]
  runs-on: ubuntu-latest
```

### 4.2. Шаги выполнения

1. **Checkout infra-gitops:**
   ```yaml
   - uses: actions/checkout@v4
     with:
       repository: soft-yt/infra-gitops
       token: ${{ secrets.INFRA_GITOPS_TOKEN }}
   ```

2. **Обновление тегов образов:**
   ```bash
   # Используя yq для обновления kustomization.yaml
   for overlay in apps/$SERVICE_NAME/overlays/*/; do
     yq eval ".images[] |= select(.name == \"ghcr.io/soft-yt/$SERVICE_NAME-backend\").newTag = \"${{ github.sha }}\"" -i $overlay/kustomization.yaml
     yq eval ".images[] |= select(.name == \"ghcr.io/soft-yt/$SERVICE_NAME-frontend\").newTag = \"${{ github.sha }}\"" -i $overlay/kustomization.yaml
   done
   ```

3. **Создание PR:**
   ```bash
   git config user.name "github-actions[bot]"
   git config user.email "github-actions[bot]@users.noreply.github.com"
   git checkout -b "auto-update/$SERVICE_NAME-${{ github.sha }}"
   git add apps/$SERVICE_NAME/overlays/*/kustomization.yaml
   git commit -m "chore(gitops): update $SERVICE_NAME to ${{ github.sha }}"
   git push origin "auto-update/$SERVICE_NAME-${{ github.sha }}"

   gh pr create \
     --title "Update $SERVICE_NAME to ${{ github.sha }}" \
     --body "Automated update from CI/CD pipeline" \
     --base main
   ```

### 4.3. Особенности

- **Идемпотентность:** Повторный запуск с тем же SHA не создает дублирующих PR
- **Branch protection:** PR требует ревью перед merge (настраивается в GitHub)
- **Автоматический merge:** (опционально) можно настроить auto-merge после успешных проверок

## 5. Релизная стратегия
- Тегировать релизы в сервисном репозитории (`vX.Y.Z`), чтобы триггерить промо-пайплайн (этап планируется).
- Опционально использовать GitHub Environments (`dev`, `staging`, `prod`) для ручных approval.

## 6. Секреты и безопасность

### 6.1. Необходимые GitHub Secrets

Каждый сервисный репозиторий должен иметь следующие secrets:

- **GHCR_PAT:** Personal Access Token для публикации образов в GitHub Container Registry
- **INFRA_GITOPS_TOKEN:** PAT с правами на создание PR в репозитории `infra-gitops`
- **COSIGN_KEY:** (опционально) Ключ для подписи контейнеров

### 6.2. Настройка безопасности

1. **OIDC-федерация:**
   - Настроить OIDC для доступа к облачным реестрам (YC/VK) без статических ключей
   - Избегать хранения долгоживущих токенов

2. **Подпись образов:**
   - Подписывать контейнеры через Cosign после публикации
   - Argo CD проверяет подписи перед развертыванием через ImagePolicy

3. **Branch protection:**
   - Требовать успешного прохождения CI для merge PR
   - Настроить required checks: `backend`, `frontend`

### 6.3. Разделение окружений

Использовать GitHub Environments для разделения прав доступа:

```yaml
jobs:
  deploy-prod:
    environment: production
    # Требует manual approval для prod деплоя
```

## 7. Мониторинг и отладка

### 7.1. Логирование
- Все jobs пишут структурированные логи в GitHub Actions
- Сохранять артефакты тестов для анализа

### 7.2. Нотификации
- Настроить GitHub Actions notifications в Slack/Teams
- Алерты на неуспешные билды

### 7.3. Метрики
- Время выполнения jobs
- Частота успешных/неуспешных билдов
- Время от коммита до деплоя (DORA metrics)

## 8. Различия с монорепо архитектурой

### Было (монорепо):
- Деплой манифесты в том же репозитории (`deploy/`)
- CI обновлял манифесты локально
- Одна синхронизация Argo CD

### Стало (multi-repo):
- Деплой манифесты в отдельном репозитории (`infra-gitops`)
- CI создает PR в другой репозиторий
- Разделение ответственности: код vs конфигурация

### Преимущества multi-repo:
- Централизованное управление всеми развертываниями
- История изменений конфигурации отдельно от кода
- Упрощенный аудит и rollback
- Возможность управлять несколькими сервисами из одного места

## 9. Открытые вопросы
- Авто-merge GitOps PR или обязательный review?
- Минимальная матрица тестов (версии Go, Node) для template репозитория.
- Механизм промоушена релизов (GitHub Environments vs Argo Image Updater).
- Ретеншн политика для образов в GHCR.
