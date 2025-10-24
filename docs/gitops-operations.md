# Руководство по GitOps-операциям

**Статус документа:** Active · **Аудитория:** платформа/SRE.

## Обзор

Репозиторий `infra-gitops` является единым источником истины (Single Source of Truth) для всех развертываний на платформе. Он содержит Kustomize манифесты, конфигурацию кластеров и платформенную документацию.

- **Репозиторий:** https://github.com/soft-yt/infra-gitops
- **Связь с сервисами:** Сервисы создаются из template `app-base-go-react`, их манифесты размещаются здесь
- **Управление:** Argo CD синхронизирует состояние кластеров с этим репозиторием

## 1. Структура репозитория (`infra-gitops`)
```
infra-gitops/
├── apps/                      # Kustomize манифесты приложений
│   └── webapp/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           ├── staging/ (план)
│           └── prod/
├── clusters/                  # Конфигурация кластеров и Argo CD
│   ├── yc-dev/
│   │   └── argo-cd/
│   ├── vk-prod/
│   │   └── argo-cd/
│   └── onprem-lab/
│       └── argo-cd/
├── docs/                      # Платформенная документация
└── secrets/                   # Зашифрованные секреты (SOPS)
    └── dev/
```

## 2. Пример ApplicationSet
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: webapp-appset
spec:
  generators:
    - git:
        repoURL: https://github.com/soft-yt/infra-gitops
        revision: HEAD
        directories:
          - path: apps/webapp/overlays/*
  template:
    metadata:
      name: webapp-{{path.basename}}
    spec:
      project: default
      source:
        repoURL: https://github.com/soft-yt/infra-gitops
        path: {{path}}
        targetRevision: HEAD
      destination:
        namespace: default
        server: https://kubernetes.default.svc
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## 3. Добавление нового приложения в GitOps

Когда сервис создан из template `app-base-go-react`, необходимо добавить его манифесты в `infra-gitops`:

### 3.1. Создание структуры приложения

```bash
# Создать директорию для нового сервиса
mkdir -p apps/<service-name>/{base,overlays/{dev,staging,prod}}

# Создать base манифесты
cd apps/<service-name>/base/
```

### 3.2. Пример base манифестов

**deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <service-name>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <service-name>
  template:
    metadata:
      labels:
        app: <service-name>
    spec:
      containers:
      - name: backend
        image: ghcr.io/soft-yt/<service-name>-backend:latest
        ports:
        - containerPort: 8080
      - name: frontend
        image: ghcr.io/soft-yt/<service-name>-frontend:latest
        ports:
        - containerPort: 80
```

**service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: <service-name>
spec:
  selector:
    app: <service-name>
  ports:
  - name: http
    port: 80
    targetPort: 80
```

**kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
```

### 3.3. Создание overlays

Для каждого окружения создать `overlays/<env>/kustomization.yaml` с переопределениями:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
images:
  - name: ghcr.io/soft-yt/<service-name>-backend
    newTag: <git-sha>
  - name: ghcr.io/soft-yt/<service-name>-frontend
    newTag: <git-sha>
patchesStrategicMerge:
  - replica-patch.yaml
```

### 3.4. Обновление ApplicationSet

Добавить или обновить ApplicationSet в `clusters/<cluster>/argo-cd/` для автоматического деплоя.

## 4. Правила для окружений
- Overlays описывают теги образов, реплики, ingress-хосты, аннотации для Vault.
- Лейблы кластеров (`cloud=yc|sber|vk|onprem`, `env=dev|prod`) управляют мультикластерным флоу.
- Секреты хранятся в SOPS (`secrets/*.enc.yaml`) и расшифровываются при деплое через Argo CD plugin.

## 5. Операционные действия

### 5.1. Bootstrap нового кластера
1. Установить Argo CD в кластер
2. Настроить доступ к `infra-gitops` репозиторию
3. Применить ApplicationSet из `clusters/<cluster>/argo-cd/`
4. Проверить синхронизацию приложений

### 5.2. Обновление образов (Deployment)
CI/CD pipeline автоматически создает PR в `infra-gitops` с новыми тегами:
1. GitHub Actions собирает образы и публикует в GHCR
2. Job `gitops-update` обновляет теги в `apps/<service>/overlays/*/kustomization.yaml`
3. Создается PR для ревью
4. После merge Argo CD автоматически синхронизирует изменения

### 5.3. Промоушен между окружениями
Для промоушена из dev в prod:
```bash
# Скопировать тег из dev overlay в prod
cd apps/<service>/overlays/
yq eval '.images[0].newTag' dev/kustomization.yaml | \
  xargs -I {} yq eval '.images[0].newTag = "{}"' -i prod/kustomization.yaml
```

### 5.4. Rollback
```bash
# Откатить последний коммит
git revert HEAD
git push origin main

# Argo CD автоматически синхронизирует предыдущее состояние
```

### 5.5. Управление дрифтом
- Включить `selfHeal: true` в ApplicationSet для автоматического исправления
- Настроить алерты Argo CD → Grafana/Alertmanager на события OutOfSync

## 6. Безопасность и комплаенс
- Ограничивать namespace'ы через Argo CD Projects (repo/path whitelists).
- Включить ImagePolicy и Cosign, чтобы пропускать только подписанные образы.
- Вести журнал: подключить Argo CD Notifications к Slack/Teams на события sync/fail/rollback.
- Все секреты шифруются через SOPS перед коммитом в репозиторий.

## 7. Связь с сервисными репозиториями

### 7.1. Workflow создания сервиса

```
1. Создать репозиторий из template app-base-go-react
   ↓
2. Разработать и протестировать локально
   ↓
3. Push → GitHub Actions собирает образы → GHCR
   ↓
4. GitHub Actions создает PR в infra-gitops
   ↓
5. Review и merge PR
   ↓
6. Argo CD деплоит в кластеры
```

### 7.2. Обновление манифестов

Манифесты в `infra-gitops` обновляются двумя способами:

1. **Автоматически** (теги образов):
   - CI/CD pipeline сервиса обновляет `images[].newTag` в overlays
   - Создается PR для ревью

2. **Вручную** (конфигурация):
   - Изменения ConfigMap, replicas, resources и т.д.
   - Коммит напрямую или через PR в `infra-gitops`

## 8. Открытые вопросы
- Настроить окна синхронизации для продового окружения (например, рабочие часы).
- Определить правила ручных sync при критических изменениях (ingress, секреты).
- Выбрать инструмент для секретов (Argo CD Vault Plugin или External Secrets Operator).
- Автоматизировать создание структуры приложения в `infra-gitops` при создании нового сервиса.
