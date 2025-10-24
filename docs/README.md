# Индекс платформенной документации

Этот индекс собирает материалы Doc-Driven Development, развёрнутые из `plan.md`.

## Репозитории платформы

Платформа построена на основе мультирепозиторной архитектуры:

- **[app-base-go-react](https://github.com/soft-yt/app-base-go-react)** — GitHub template репозиторий для создания новых сервисов Go + React
- **[infra-gitops](https://github.com/soft-yt/infra-gitops)** — GitOps репозиторий с Kustomize манифестами, конфигурацией Argo CD и платформенной документацией

## Процессы и методология

- [Руководство по Doc-Driven Development](doc-driven-development.md) — процесс работы с документами и ритуалы ревью.

## Архитектура и проектирование

- [Архитектурный обзор](architecture-overview.md) — целевой поток платформы, мультирепозиторная архитектура и зоны ответственности компонентов.
- [Шаблон сервиса: app-base-go-react](service-template-app-base-go-react.md) — GitHub template для новых сервисов, структура, стандарты, расширение.

## API и контракты

- [API-контракты и спецификации](api-contracts.md) — детальное описание REST API, форматы запросов/ответов, validation rules, acceptance criteria.

## Тестирование (TDD)

- [Спецификация тестирования](testing-specification.md) — стратегия тестирования, unit/integration/E2E тесты, test cases, coverage requirements.
- [Спецификация тестовых данных](test-data-specification.md) — управление fixtures, моками, factories и seed данных для тестирования.
- [Примеры референсной реализации](implementation-examples.md) — примеры кода backend/frontend, тестов, Dockerfile, конфигураций.

## Качество и процессы

- [Definition of Done (DoD)](definition-of-done.md) — критерии завершенности для различных типов задач, чеклисты для features, bug fixes, releases.

## CI/CD и GitOps

- [Спецификация CI/CD](ci-cd-pipeline.md) — конвейер GitHub Actions, публикация образов, обновление GitOps.
- [GitOps-операции](gitops-operations.md) — структура репозитория, ApplicationSet, оперирование.

## Инфраструктура

- [Инфраструктура и платформенные сервисы](infrastructure-platform.md) — кластеры, сеть, секреты, наблюдаемость.

## Разработка

- [Плейбук локальной разработки](local-development.md) — требования, режимы запуска, тестирование.
- [Спецификация генератора сервисов](service-generator-specification.md) — CLI/Backstage инструмент для создания сервисов из шаблонов.

## Внедрение

- [Дорожная карта внедрения](implementation-roadmap.md) — поэтапный план и журнал рисков.

## Спецификации реализации (DDD/TDD)

Детальные технические спецификации для каждой фазы разработки:

### Активные фазы
- **[Phase 2: Observability, Security & Secrets](phase2-observability-security-spec.md)** — SOPS, Vault, Prometheus, Grafana, Loki, Tempo, rate limiting, security testing, Traefik ingress (В РАБОТЕ)

### Завершенные фазы
- **[Phase 1: Foundation](archive/phase1/phase1-foundation-spec.md)** — Service + Repository layers, PostgreSQL, Clean Architecture (✅ ЗАВЕРШЕНО 2025-10-23, 73% coverage)

## Организация документации

Документация организована по принципу Domain-Driven Development:

### Активные документы
Текущая документация находится в корне `docs/`:
- Архитектура, процессы, спецификации
- DoD, API-контракты, тестирование
- CI/CD, GitOps, инфраструктура

### Отчеты и результаты
- **[reports/](reports/)** — текущие отчеты о реализации, статусы фаз (пусто после миграции в archive)

### Архив
- **[archive/](archive/)** — завершенные материалы, организованные по типу/контексту (DDD):
  - `archive/plans/` — исходные планы и спецификации
  - `archive/phase1/` — Phase 1: Foundation (ЗАВЕРШЕНО 2025-10-23)
  - `archive/migration/` — Repository Migration (ЗАВЕРШЕНО 2025-10-23)
  - `archive/platform/` — архивные версии платформенной документации

Подробнее см. [archive/README.md](archive/README.md)

**Принцип организации:** Type over Time. Domain over Date. Context over Chronology.

---

> Документы должны оставаться живыми: обновляйте статус, фиксируйте решения и добавляйте новые материалы в этот индекс.
