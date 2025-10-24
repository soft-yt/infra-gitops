# Архитектурный обзор

**Статус документа:** Active · **Аудитория:** платформенная команда · **Источник:** `plan.md`

## 1. Цели платформы
- Единый поток: генерация сервисов Go + React → сборка контейнеров → доставка в мультиоблачные и on-prem кластеры Kubernetes.
- GitHub выступает управляющим контуром: шаблоны, CI/CD и GitOps-репозитории живут в `github.com/soft-yt/`.
- Argo CD через ApplicationSet поддерживает желаемое состояние во всех кластерах; секреты остаются зашифрованными или подтягиваются во время выполнения.

## 2. Мультирепозиторная архитектура

Платформа построена на принципе разделения ответственности между двумя основными репозиториями:

### 2.1. app-base-go-react (GitHub Template)
- **Назначение:** Шаблон для создания новых сервисов
- **URL:** https://github.com/soft-yt/app-base-go-react
- **Содержит:**
  - `backend/` — Go backend с chi router
  - `frontend/` — React + Vite + TypeScript frontend
  - `.github/workflows/` — CI/CD pipeline для сборки и публикации образов
  - `docker-compose.yml` — локальная разработка
  - `TEMPLATE-README.md` — инструкции по использованию шаблона

### 2.2. infra-gitops (GitOps Repository)
- **Назначение:** Централизованное управление развертываниями
- **URL:** https://github.com/soft-yt/infra-gitops
- **Содержит:**
  - `apps/` — Kustomize манифесты приложений (base + overlays)
  - `clusters/` — конфигурация кластеров и Argo CD
  - `docs/` — платформенная документация
  - `secrets/` — зашифрованные секреты (SOPS)

### 2.3. Взаимодействие репозиториев

```
[Developer]
    ↓ 1. Use GitHub Template
[app-base-go-react] ──────→ [new-service-repo]
    ↓ 2. Develop & Push
[GitHub Actions CI]
    ↓ 3. Build & Push Images
[GHCR: ghcr.io/soft-yt/new-service-*]
    ↓ 4. Update GitOps (PR or direct commit)
[infra-gitops/apps/new-service/overlays/*/]
    ↓ 5. Argo CD sync
[Target Clusters: YC/VK/OnPrem]
```

## 3. Общий поток развертывания
```
Разработчик → создание из template → GitHub Actions CI → образы в GHCR
→ обновление infra-gitops → Argo CD ApplicationSet → целевые кластеры
```

- Сервисы создаются через GitHub Template или CLI на основе `app-base-go-react`.
- CI собирает и публикует образы backend/frontend в GHCR, после чего обновляет GitOps-репозиторий новыми тегами.
- Argo CD синхронизирует манифесты в кластерах (YC, Sber, VK, on-prem) через генератор ApplicationSet по каждому overlay.

## 4. Ключевые компоненты
### Шаблон сервиса (`app-base-go-react`)
- GitHub Template репозиторий с Go backend (`backend/`) и React frontend (`frontend/`), каждый собирается в Docker-образ.
- Содержит CI/CD pipeline в `.github/workflows/` для автоматической сборки и публикации.
- НЕ содержит деплой-манифестов — они размещаются в отдельном репозитории `infra-gitops`.

### CI/CD (`.github/workflows/ci.yml`)
- Два job (`backend`, `frontend`) собирают и пушат Docker-образы через Buildx в `ghcr.io/soft-yt/`.
- После успешной сборки создается PR в `infra-gitops` репозиторий с обновленными тегами образов.
- Использует GitHub PAT для доступа к GHCR и обновления GitOps репозитория.

### GitOps (`infra-gitops`)
- `apps/` — Kustomize манифесты приложений: `apps/webapp/base/` (общие ресурсы) + `apps/webapp/overlays/` (окружения).
- `clusters/` — конфигурация для каждого кластера (YC, VK, on-prem) и настройки Argo CD.
- ApplicationSet именует приложения `webapp-<overlay>` и направляет их в namespace `default`, включая автоматический sync (prune + selfHeal).

### Инфраструктура и наблюдаемость
- Кластеры Kubernetes в YC/Sber/VK и on-prem; в каждом установлен Argo CD.
- Секреты: в Git шифруются через SOPS (age), во время выполнения подгружаются из Vault; авторизация GitHub Actions через OIDC.
- Наблюдаемость: Prometheus, Grafana, Loki, Tempo; по необходимости сервис-меш (Istio/Linkerd), а также ExternalDNS и cert-manager.

## 5. Ответственности в мультирепозиторной архитектуре

### Платформенная команда
- Поддерживает `app-base-go-react` template и обновляет его новыми возможностями
- Управляет `infra-gitops` репозиторием: структура, ApplicationSets, cluster configs
- Разрабатывает и поддерживает CI/CD pipeline в template
- Управляет общими инфраструктурными модулями и платформенными сервисами

### Команды сервисов
- Создают новые сервисы из GitHub Template `app-base-go-react`
- Разрабатывают и поддерживают код своих сервисов в собственных репозиториях
- Создают PR в `infra-gitops` для добавления новых приложений или изменения конфигурации
- Соблюдают правила template и платформенные стандарты

### Команда безопасности
- Управляет политиками Vault и ключами SOPS для шифрования секретов в `infra-gitops`
- Настраивает правила подписи образов (Cosign + Argo CD ImagePolicy)
- Аудитирует доступ к GHCR и GitOps репозиторию

## 6. Открытые вопросы
- Определить стратегию ingress по умолчанию для окружений (Istio Gateway или Traefik).
- Закрепить ответственность за развёртывание и поддержку стека наблюдаемости (платформа или SRE).
- Автоматический vs ручной merge PR в infra-gitops после CI/CD.
