# Archive - Completed Documentation

Эта директория содержит завершенные/законченные материалы, организованные по типу (DDD Bounded Contexts).

## Структура (DDD-подход)

```
archive/
├── plans/              # Планы и исходные спецификации
├── phase1/             # Phase 1: Foundation (ЗАВЕРШЕНО 2025-10-23)
├── migration/          # Repository Migration (ЗАВЕРШЕНО 2025-10-23)
├── platform/           # Platform Documentation (архивные версии)
└── README.md           # Этот файл
```

## Принципы организации

Следуя **Domain-Driven Development**, документы группируются по **типу/контексту**, а не по датам:

### 1. plans/ - Планы и Спецификации
Оригинальные планы и спецификации (до реализации):
- `plan-original-20251023.md` - Исходный универсальный платформенный план

### 2. phase1/ - Phase 1: Foundation
Отчеты о реализации Phase 1 (Service + Repository layers):
- `phase1-foundation-spec.md` - Исходная DDD/TDD спецификация Phase 1
- `PHASE1-IMPLEMENTATION-REPORT.md` - Детальный отчет реализации
- `PHASE1-FINAL-STATUS.md` - Финальный статус и достижения
- `PHASE1-SUMMARY.md` - Краткая сводка

**Статус:** ✅ ЗАВЕРШЕНО 2025-10-23
**Достижения:**
- Service Layer: 81.2% coverage
- Repository Layer: 81.1% coverage
- PostgreSQL integration
- Database migrations
- Overall coverage: 73%

### 3. migration/ - Repository Migration
Документы миграции от monorepo к multi-repo:
- `MIGRATION-COMPLETE.md` - Полный отчет о миграции
- `REPOSITORY-STRUCTURE-PLAN.md` - План миграции и архитектура

**Статус:** ✅ ЗАВЕРШЕНО 2025-10-23
**Достижения:**
- Создан infra-gitops репозиторий
- app-base-go-react настроен как GitHub Template
- GitOps манифесты мигрированы
- Документация актуализирована

### 4. platform/ - Platform Documentation
Архивные версии платформенной документации:
- `DEPLOYMENT.md` - Процедуры деплоя
- `AGENTS.md` - Документация DDD/TDD агентов

## Правила архивирования

### Когда перемещать в archive:

1. **Завершенные фазы** → `archive/phaseN/`
   - Когда фаза полностью реализована
   - Все DoD критерии выполнены
   - Отчеты о завершении созданы

2. **Завершенные миграции** → `archive/migration/`
   - Миграция успешно выполнена
   - Новая архитектура в продакшене
   - Отчет о завершении создан

3. **Устаревшие планы** → `archive/plans/`
   - План полностью реализован
   - Заменен новой версией
   - Представляет исторический интерес

4. **Устаревшая документация** → `archive/platform/`
   - Документ заменен новой версией
   - Содержит устаревшую информацию
   - Сохраняется для истории

### Когда НЕ архивировать:

- ❌ Активная документация (остается в `docs/`)
- ❌ Текущие/незавершенные фазы
- ❌ Планы в процессе реализации

## Навигация

### Текущая документация
Актуальная платформенная документация находится в [../](../):
- [Architecture Overview](../architecture-overview.md)
- [GitOps Operations](../gitops-operations.md)
- [CI/CD Pipeline](../ci-cd-pipeline.md)
- [Implementation Roadmap](../implementation-roadmap.md) - Текущий статус

### Отчеты
Активные/текущие отчеты находятся в [../reports/](../reports/)

## Timeline

| Период | Событие | Документы | Статус |
|--------|---------|-----------|--------|
| 2025-10-23 | Initial Platform Setup | plans/plan-original | ✅ Completed |
| 2025-10-23 | Phase 1: Foundation | phase1/* | ✅ Completed |
| 2025-10-23 | Multi-Repo Migration | migration/* | ✅ Completed |

## Версионирование

Архивные документы сохраняют свои оригинальные названия и содержимое.
Если нужны версии:
```
archive/
└── platform/
    ├── DEPLOYMENT-v1.0-20251023.md
    └── DEPLOYMENT-v2.0-20251124.md
```

## Поиск по архиву

```bash
# Найти все отчеты Phase 1
find archive/phase1 -type f

# Найти документы по ключевому слову
grep -r "coverage" archive/

# Показать структуру
tree archive/
```

---

**Принцип:** Организация по типу/контексту (DDD), не по дате. Это упрощает навигацию и соответствует принципам Domain-Driven Development.
