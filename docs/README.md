# Индекс платформенной документации

Этот индекс собирает материалы Doc-Driven Development, развёрнутые из `plan.md`.

## Процессы и методология

- [Руководство по Doc-Driven Development](doc-driven-development.md) — процесс работы с документами и ритуалы ревью.

## Архитектура и проектирование

- [Архитектурный обзор](architecture-overview.md) — целевой поток платформы и зоны ответственности компонентов.
- [Шаблон сервиса: app-base-go-react](service-template-app-base-go-react.md) — структура монорепозитория, стандарты, расширение.

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

---

> Документы должны оставаться живыми: обновляйте статус, фиксируйте решения и добавляйте новые материалы в этот индекс.
