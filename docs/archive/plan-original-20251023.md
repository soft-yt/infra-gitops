# Универсальный платформенный марш‑план (GitHub → YC / Sber / VK / on‑prem)

> **Цель:** построить единую Dev‑платформу на базе GitHub и Kubernetes, позволяющую создавать и доставлять приложения (Go + React) в любую инфраструктуру — облака (Yandex Cloud, SberCloud, VK Cloud) и on‑prem‑кластеры. Всё должно работать по принципу Backstage: от шаблона до продакшена — из одного CLI или UI.

---

## 1. Архитектурная схема

```text
Dev → GitHub (repo template) → GitHub Actions (build & push) → GitOps repo → Argo CD → K8s (YC / Sber / VK / on‑prem)
```

### Основные элементы:

* **Шаблоны сервисов**: Go + React (монорепо), создаются командой или через Backstage.
* **CI/CD**: GitHub Actions — build → push → обновление `infra-gitops` репозитория.
* **GitOps**: Argo CD (ApplicationSet) синхронизирует состояния во всех кластерах.
* **Инфра**: Terraform / Crossplane (для создания кластеров и сервисов облаков).
* **Секреты**: SOPS (age) + Vault (runtime‑секреты).
* **Observability**: Prometheus, Grafana, Loki, Tempo.

---

## 2. Основные репозитории

```text
github.com/soft-yt/
├── app-base-go-react/        # Базовый шаблон (Go backend + React frontend)
├── infra-gitops/             # GitOps‑репозиторий для Argo CD
└── templates/                # (опционально) Backstage software templates
```

---

## 3. Структура шаблона `app-base-go-react`

Монорепо для Go + React.

```
app-base-go-react/
├── backend/
│   ├── cmd/api/main.go
│   ├── internal/config/config.go
│   ├── internal/http/handlers.go
│   ├── go.mod
│   ├── Dockerfile
│   └── Makefile
├── frontend/
│   ├── src/App.tsx
│   ├── src/main.tsx
│   ├── package.json
│   ├── vite.config.ts
│   └── Dockerfile
├── deploy/kustomize/apps/webapp/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── overlays/dev/kustomization.yaml
├── .github/workflows/ci.yml
├── docker-compose.yml
└── README.md
```

**Назначение:**

* Бэкенд — API на Go (chi router), порт `8080`.
* Фронтенд — React + Vite, порт `5173`, проксирует `/api` на бэкенд.
* Оба компонента контейнеризованы и могут разворачиваться совместно в Kubernetes.

---

## 4. CI/CD (GitHub Actions)

Workflow `.github/workflows/ci.yml` собирает и пушит два образа:

```yaml
jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GHCR_PAT }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          file: backend/Dockerfile
          push: true
          tags: ghcr.io/soft-yt/app-base-go-react-backend:${{ github.sha }}

  frontend:
    runs-on: ubuntu-latest
    needs: backend
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GHCR_PAT }}
      - uses: docker/build-push-action@v6
        with:
          context: .
          file: frontend/Dockerfile
          push: true
          tags: ghcr.io/soft-yt/app-base-go-react-frontend:${{ github.sha }}
```

> После сборки workflow может автоматически обновлять теги образов в `infra-gitops` и коммитить изменения.

---

## 5. GitOps (репозиторий `infra-gitops`)

**Структура:**

```text
infra-gitops/
├── clusters/
│   ├── yc-dev/
│   ├── vk-prod/
│   └── onprem-lab/
└── apps/
    └── webapp/
        ├── base/
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   └── kustomization.yaml
        └── overlays/dev/
            └── kustomization.yaml
```

**Argo CD ApplicationSet:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: webapp-appset
spec:
  generators:
    - git:
        repoURL: 'https://github.com/soft-yt/infra-gitops'
        revision: HEAD
        directories:
          - path: 'apps/webapp/overlays/*'
  template:
    metadata:
      name: 'webapp-{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/soft-yt/infra-gitops'
        path: '{{path}}'
        targetRevision: HEAD
      destination:
        namespace: default
        server: 'https://kubernetes.default.svc'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

---

## 6. Kubernetes и инфраструктура

**Kustomize base:** объединяет два контейнера (frontend + backend) в одном Pod:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 1
  selector:
    matchLabels: { app: webapp }
  template:
    metadata:
      labels: { app: webapp }
    spec:
      containers:
        - name: backend
          image: ghcr.io/soft-yt/app-base-go-react-backend:latest
          ports: [{containerPort: 8080}]
        - name: frontend
          image: ghcr.io/soft-yt/app-base-go-react-frontend:latest
          ports: [{containerPort: 80}]
```

**Service:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  type: ClusterIP
  selector: { app: webapp }
  ports:
    - name: http
      port: 80
      targetPort: 80
```

---

## 7. Мультикластер / мультиклауд

* Разворачивайте Argo CD в каждом целевом кластере.
* Используйте **ApplicationSet** для автоматического распределения по окружениям.
* Лейблы кластеров: `cloud=yc|sber|vk|onprem`, `env=dev|prod`.
* Разделение ingress‑хостов через overlays (`dev.localhost`, `prod.company.ru`).

---

## 8. Секреты и безопасность

* **SOPS (age)** для GitOps‑секретов.
* **Vault** для runtime (через k8s auth или CSI driver).
* **OIDC‑федерация** GitHub → облака для отказа от постоянных ключей.
* Подпись образов с **Cosign**, валидация через ArgoCD ImagePolicy.

---

## 9. Observability и сеть

* **Istio Gateway / Linkerd** — сервис‑мэш.
* **ExternalDNS** — динамические DNS.
* **Prometheus + Grafana + Loki + Tempo** — мониторинг, логирование, трейсинг.
* **cert-manager** — TLS‑сертификаты.

---

## 10. Локальная разработка

* `docker-compose up` — backend + frontend.
* `make -C backend run` и `npm run dev` для раздельного режима.
* **kind/k3d** — локальный Kubernetes.
* **Traefik** или **Istio** для маршрутов `http://dev.localhost/webapp/`.

---

## 11. Backstage или CLI‑генератор

**Backstage template** создаёт:

1. Репозиторий из шаблона `app-base-go-react`.
2. Добавляет CI.
3. Создаёт PR в `infra-gitops`.

**CLI‑утилита (альтернатива):**

* `x5 service create --template go-react --name myapp`.
* Команда генерирует код, пушит репо и создаёт GitOps‑манифест.

---

## 12. План внедрения (1–2 недели)

**Неделя 1:**

* [ ] Развернуть 1 кластер (YC/Sber/VK или on‑prem).
* [ ] Установить Argo CD и настроить GitOps sync с `infra-gitops`.
* [ ] Создать репо `app-base-go-react` и проверить CI build → push.

**Неделя 2:**

* [ ] Подключить второй кластер (для мультиклауда).
* [ ] Внедрить SOPS и Vault.
* [ ] Добавить ingress + observability stack.
* [ ] Настроить Backstage template или CLI‑генератор.

---

## 13. Следующие шаги

* Добавить шаблоны Python / Java сервисов.
* Ввести Helm chart для комплексных приложений.
* Включить Crossplane для управления облачными ресурсами (БД, bucket, DNS).
* Настроить CI promotion через ArgoCD image updater.

---

**Результат:**
Платформа `soft-yt` позволяет создавать и доставлять сервисы Go + React в любую инфраструктуру (облака или on‑prem) по GitOps‑принципам с единой цепочкой CI/CD и безопасной федерацией учётных данных.
