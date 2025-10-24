# Дорожная карта внедрения

**Статус документа:** Active · **Аудитория:** лиды платформы и менеджеры проекта.

## Статус миграции: ЗАВЕРШЕНА

Платформа успешно мигрирована с монорепозиторной на мультирепозиторную архитектуру.

### Основные достижения
- Репозиторий `app-base-go-react` настроен как GitHub Template
- Создан репозиторий `infra-gitops` для централизованного управления деплоями
- CI/CD pipeline обновлен для работы с GHCR и GitOps
- Документация актуализирована и размещена в `infra-gitops/docs/`

---

## Неделя 1: База - ЗАВЕРШЕНО
- [x] Поднять первый кластер Kubernetes (YC/Sber/VK/on-prem) с базовой сетью.
- [x] Установить Argo CD, подключить `infra-gitops`, убедиться в синхронизации `webapp-dev` через ApplicationSet.
- [x] Завершить структуру шаблона `app-base-go-react` как GitHub Template.
- [x] Настроить GitHub Actions для сборки и публикации образов backend/frontend в GHCR.
- [x] Реализовать job `gitops-update` для автоматического обновления манифестов.
- [x] Мигрировать деплой манифесты из `app-base-go-react/deploy/` в `infra-gitops/apps/`.
- [x] Обновить документацию для отражения мультирепозиторной архитектуры.

## Неделя 2: Расширение окружений - В ПРОЦЕССЕ

**Начало:** 2025-10-24
**Фокус:** Инфраструктура + Phase 2 (Observability, Security, Secrets)

### Задачи Week 2

#### Infrastructure (YC Dev Cluster) - ✅ ЗАВЕРШЕНО
- [x] Настроить Yandex Cloud CLI
- [x] Создать service accounts с IAM ролями
- [x] Создать Kubernetes cluster `soft-yt-dev`
- [x] Создать node group (3 ноды, preemptible)
- [x] Настроить kubectl
- [x] Установить Argo CD v2.11.0
- [x] Создать ApplicationSet для multi-cluster sync
- [x] Настроить NAT Gateway для internet access
- [x] Развернуть Traefik ingress controller
- [x] Настроить cert-manager с Let's Encrypt

**Документация:**
- [infrastructure-platform.md](infrastructure-platform.md)
- [WEEK2-INFRASTRUCTURE-COMPLETE.md](reports/WEEK2-INFRASTRUCTURE-COMPLETE.md)

**Automation:**
- `clusters/yc-dev/create-node-group.sh`
- `clusters/yc-dev/argo-cd/install.sh`

#### Phase 2: Observability, Security & Secrets - ⏳ В ПРОЦЕССЕ

**Спецификация:** [phase2-observability-security-spec.md](phase2-observability-security-spec.md)

**Phase 2.1 - Observability (Monitoring) - ✅ ЗАВЕРШЕНО:**
- [x] Развернуть Prometheus (retention 7d, persistent storage 10Gi)
- [x] Развернуть Grafana (persistent storage 5Gi, pre-configured dashboards)
- [x] Развернуть Alertmanager (HA mode)
- [x] Настроить Node Exporters (3 nodes)
- [x] Настроить Kube State Metrics
- [x] Создать Ingress для Grafana: https://grafana.dev.tulupov.org
- [x] Настроить Let's Encrypt TLS для Grafana

**Отчет:** [OBSERVABILITY-STACK-DEPLOYED.md](reports/OBSERVABILITY-STACK-DEPLOYED.md)

**Phase 2.2 - Logging - ✅ ЗАВЕРШЕНО:**
- [x] Развернуть Loki для log aggregation (v2.6.1, 10Gi storage)
- [x] Настроить Promtail для log collection (DaemonSet на 3 нодах)
- [x] Интегрировать Loki с Grafana (data source configured)
- [x] Верифицировать сбор логов (24 jobs из 5 namespaces)

**Отчет:** [LOGGING-STACK-DEPLOYED.md](reports/LOGGING-STACK-DEPLOYED.md)

**Phase 2.3 - Tracing - ✅ ЗАВЕРШЕНО:**
- [x] Развернуть Tempo для distributed tracing (v2.8.2, 10Gi storage)
- [x] Настроить OTLP receivers (gRPC 4317, HTTP 4318)
- [x] Интегрировать Tempo с Grafana (data source configured)
- [x] Настроить traces-to-logs correlation с Loki
- [x] Настроить traces-to-metrics correlation с Prometheus
- [x] Включить Service Map и Node Graph

**Отчет:** [TRACING-STACK-DEPLOYED.md](reports/TRACING-STACK-DEPLOYED.md)

**Phase 2.4 - Security & Secrets - ⏳ В ПРОЦЕССЕ:**
- [x] Интегрировать SOPS для шифрования секретов (age encryption)
- [x] Создать age ключи для yc-dev окружения
- [x] Настроить Argo CD с SOPS tools
- [x] Создать документацию SOPS workflow
- [ ] Интегрировать Vault для централизованного управления секретами
- [ ] Реализовать rate limiting middleware
- [ ] Добавить security headers и CORS middleware
- [ ] Добавить security testing в CI/CD (OWASP Top 10)

**Отчет SOPS:** [SOPS-SECRETS-MANAGEMENT.md](SOPS-SECRETS-MANAGEMENT.md)

**Phase 2.5 - DNS Automation (TODO):**
- [ ] Интегрировать ExternalDNS для автоматического управления DNS

**Phase 2.6 - Service Templates (TODO):**
- [ ] Подготовить CLI-генератор или Backstage template для создания сервисов

## После второй недели
- [ ] Добавить шаблоны сервисов на Python/Java для расширения покрытия.
- [ ] Подготовить Helm chart для сложных приложений.
- [ ] Включить автоматический промоушен образов (Argo CD Image Updater или свой workflow).
- [ ] Внедрить Crossplane-модули для ресурсов облаков (БД, bucket, DNS).

## Миграция на multi-repo (Завершено)

### Выполненные задачи

1. **Разделение репозиториев:**
   - Создан `app-base-go-react` как GitHub Template
   - Создан `infra-gitops` для GitOps манифестов
   - Мигрированы деплой манифесты из монорепо

2. **Обновление CI/CD:**
   - Добавлен job `gitops-update` в GitHub Actions
   - Настроена интеграция с GHCR
   - Реализован автоматический PR в `infra-gitops`

3. **Обновление документации:**
   - Актуализирован `architecture-overview.md`
   - Обновлен `service-template-app-base-go-react.md` как guide по template
   - Дополнен `gitops-operations.md` инструкциями по добавлению сервисов
   - Расширен `ci-cd-pipeline.md` описанием multi-repo workflow
   - Обновлен `README.md` с информацией о репозиториях

### Преимущества новой архитектуры

- Централизованное управление всеми развертываниями
- Разделение ответственности: код vs конфигурация
- Упрощенный аудит и rollback
- Возможность управлять несколькими сервисами из одного места
- Template репозиторий упрощает создание новых сервисов

## Журнал решений

### Принятые решения
- **Архитектура:** Multi-repo (app-base-go-react + infra-gitops)
- **Container Registry:** GitHub Container Registry (GHCR)
- **GitOps:** Argo CD с ApplicationSet
- **Секреты:** SOPS для шифрования в Git
- **CI/CD:** GitHub Actions с автоматическим PR в infra-gitops

### TBD (To Be Decided)
- Стандарт ingress-контроллера (Istio Gateway vs Traefik)
- Матрица CI-тестов (версии Go, Node)
- Процессы релизов и промоушена
- Кто обслуживает стек наблюдаемости (платформа vs SRE)
- Периодичность и автоматизация ротации секретов
- Auto-merge vs manual review для GitOps PR

## Риски и меры

### Архитектурные риски
- **Мультиоблачный дрифт:**
  - Мера: изменения только через GitOps, аудит Argo CD
  - Статус: Контролируется через selfHeal

- **Рассинхронизация репозиториев:**
  - Мера: автоматический gitops-update job
  - Статус: Реализовано в CI/CD

### Операционные риски
- **Разрастание учёток:**
  - Мера: приоритет OIDC-федерации к облакам, минимум PAT
  - Статус: В планах на неделю 2

- **Расхождение шаблонов:**
  - Мера: обновлять template обратносовместимо, документировать миграцию
  - Статус: Процесс определен

### Безопасность
- **Утечка секретов:**
  - Мера: SOPS шифрование, Vault integration
  - Статус: SOPS реализовано, Vault в процессе

- **Неавторизованный доступ к GHCR:**
  - Мера: RBAC, package permissions, image signing
  - Статус: Базовая настройка выполнена
