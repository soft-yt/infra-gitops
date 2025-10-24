# План реструктуризации репозиториев

## Текущее состояние

**Проблема:** Все компоненты платформы находятся в одном репозитории `app-base-go-react`

```
soft-yt/app-base-go-react (CURRENT)
├── backend/           # ✅ Правильно - часть шаблона
├── frontend/          # ✅ Правильно - часть шаблона
├── deploy/            # ❌ Должно быть в infra-gitops
├── docs/              # ❌ Должно быть отдельно или в infra-gitops
└── .github/           # ✅ Правильно - CI для шаблона
```

## Целевая архитектура

### 1. app-base-go-react (Template Repository)

**Назначение:** Шаблон для создания новых сервисов

**Структура:**
```
app-base-go-react/
├── backend/
│   ├── cmd/api/
│   ├── internal/
│   ├── migrations/
│   ├── Dockerfile
│   ├── Makefile
│   └── README.md
├── frontend/
│   ├── src/
│   ├── Dockerfile
│   ├── package.json
│   └── README.md
├── .github/workflows/
│   └── ci.yml              # Собирает и пушит образы в GHCR
├── docker-compose.yml       # Для локальной разработки
├── .env.example
├── README.md               # Как использовать шаблон
└── TEMPLATE-README.md      # Инструкция для новых проектов
```

**Что содержит:**
- ✅ Backend код (структура DDD)
- ✅ Frontend код (React + TypeScript)
- ✅ CI workflow для сборки образов
- ✅ docker-compose для локальной разработки
- ✅ Примеры тестов
- ✅ Документация по использованию шаблона

**Что НЕ содержит:**
- ❌ GitOps манифесты (они в infra-gitops)
- ❌ Платформенную документацию
- ❌ Kustomize overlays

**GitHub Settings:**
- `isTemplate: true` (Template repository)
- Веб-интерфейс → Settings → Template repository ✅

### 2. infra-gitops (GitOps Repository)

**Назначение:** Управление деплоем через Argo CD

**Структура:**
```
infra-gitops/
├── README.md
├── clusters/
│   ├── yc-dev/
│   │   ├── argo-cd/
│   │   │   └── applicationset.yaml
│   │   └── config.yaml
│   ├── vk-prod/
│   │   ├── argo-cd/
│   │   └── config.yaml
│   └── onprem-lab/
│       ├── argo-cd/
│       └── config.yaml
├── apps/
│   └── webapp/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   ├── deployment-patch.yaml
│           │   ├── ingress.yaml
│           │   └── kustomization.yaml
│           ├── staging/
│           │   ├── deployment-patch.yaml
│           │   ├── ingress.yaml
│           │   └── kustomization.yaml
│           └── prod/
│               ├── deployment-patch.yaml
│               ├── ingress.yaml
│               └── kustomization.yaml
└── secrets/
    ├── .sops.yaml           # SOPS configuration
    └── dev/
        └── secrets.enc.yaml # Encrypted secrets
```

**Что содержит:**
- ✅ Kustomize base и overlays
- ✅ ApplicationSet для Argo CD
- ✅ Конфигурация кластеров
- ✅ Зашифрованные секреты (SOPS)
- ✅ Ingress/Gateway настройки

### 3. platform-docs (Платформенная документация)

**Опция A:** Отдельный репозиторий
```
platform-docs/
├── README.md
├── architecture/
│   ├── architecture-overview.md
│   ├── service-template.md
│   └── gitops-operations.md
├── development/
│   ├── local-development.md
│   ├── testing-specification.md
│   └── definition-of-done.md
├── infrastructure/
│   ├── infrastructure-platform.md
│   └── ci-cd-pipeline.md
└── guides/
    ├── service-generator-specification.md
    └── implementation-roadmap.md
```

**Опция B:** В infra-gitops/docs/
```
infra-gitops/
├── apps/
├── clusters/
└── docs/                    # Платформенная документация
    ├── architecture/
    ├── development/
    └── guides/
```

## План миграции

### Шаг 1: Создать infra-gitops репозиторий

```bash
gh repo create soft-yt/infra-gitops \
  --public \
  --description "GitOps repository for Kubernetes deployments with Argo CD"

cd /Users/yaroslav.tulupov/dev/yt-soft
mkdir infra-gitops
cd infra-gitops
git init
```

### Шаг 2: Переместить GitOps манифесты

```bash
# Копировать deploy/ → infra-gitops/apps/webapp/
cp -r ../app-base-go-react/deploy/kustomize/apps/webapp/ ./apps/webapp/

# Создать структуру кластеров
mkdir -p clusters/{yc-dev,vk-prod,onprem-lab}/argo-cd
```

### Шаг 3: Переместить документацию

**Вариант 1:** В infra-gitops
```bash
cp -r ../app-base-go-react/docs/ ./docs/
```

**Вариант 2:** Отдельный репозиторий
```bash
gh repo create soft-yt/platform-docs --public
mkdir platform-docs
cp -r ../app-base-go-react/docs/ ./platform-docs/
```

### Шаг 4: Очистить app-base-go-react

```bash
cd /Users/yaroslav.tulupov/dev/yt-soft/app-base-go-react

# Удалить GitOps манифесты
git rm -r deploy/

# Удалить платформенную документацию
git rm -r docs/

# Оставить только документацию по шаблону
cat > TEMPLATE-README.md << 'TEMPLATE'
# Service Template: app-base-go-react

This is a template repository for creating new services...
TEMPLATE
```

### Шаг 5: Настроить app-base-go-react как Template

```bash
# Через веб-интерфейс GitHub:
# 1. Settings → General → Template repository ✅
# 2. Обновить description

# Или через API
gh api repos/soft-yt/app-base-go-react -X PATCH -f is_template=true
```

### Шаг 6: Обновить CI/CD workflow

В `app-base-go-react/.github/workflows/ci.yml` добавить обновление GitOps:

```yaml
- name: Update GitOps repository
  run: |
    git clone https://github.com/soft-yt/infra-gitops.git
    cd infra-gitops
    # Update image tags in overlays
    # Create PR or direct push
```

## Использование после миграции

### Создание нового сервиса

```bash
# 1. Использовать template
gh repo create soft-yt/my-new-service \
  --template soft-yt/app-base-go-react \
  --public

# 2. Разработка
cd my-new-service
# ... код ...

# 3. CI автоматически:
#    - Собирает образы → ghcr.io/soft-yt/my-new-service-backend:v1.0.0
#    - Обновляет infra-gitops с новыми тегами

# 4. Argo CD автоматически деплоит через ApplicationSet
```

### Обновление окружения

```bash
cd infra-gitops

# Изменить overlay для staging
vim apps/webapp/overlays/staging/deployment-patch.yaml

# Коммит → Argo CD автоматически применит изменения
git add . && git commit -m "Update staging replicas to 3"
git push
```

## Преимущества новой структуры

1. **Разделение ответственности**
   - app-base-go-react: шаблон (платформенная команда)
   - infra-gitops: деплой (SRE/DevOps)
   - Сервисы: бизнес-логика (команды разработки)

2. **Масштабируемость**
   - Легко создавать новые сервисы (1 клик)
   - Централизованное управление инфраструктурой
   - Единый источник истины для деплоя

3. **Безопасность**
   - Секреты только в infra-gitops (SOPS encrypted)
   - Разные права доступа к репозиториям
   - Audit trail для изменений инфраструктуры

4. **GitOps Best Practices**
   - Соответствует паттерну Argo CD ApplicationSet
   - Мультиоблачный деплой из одного места
   - Декларативная конфигурация

## Следующие шаги

1. ✅ Создать план миграции (этот документ)
2. ⏳ Создать репозиторий infra-gitops
3. ⏳ Переместить GitOps манифесты
4. ⏳ Переместить документацию
5. ⏳ Очистить app-base-go-react
6. ⏳ Настроить как Template
7. ⏳ Обновить CI/CD workflows
8. ⏳ Документировать новую структуру
9. ⏳ Тестировать создание сервиса из template
10. ⏳ Обновить дорожную карту

