# Definition of Done (DoD)

**Статус документа:** Draft · **Аудитория:** все команды разработки и платформенная команда.

## 1. Обзор

Документ определяет критерии завершенности (Definition of Done) для различных типов задач на платформе `soft-yt`. DoD является обязательным чеклистом, который должен быть выполнен перед закрытием задачи или merge'ем Pull Request.

---

## 2. Общие критерии для всех задач

Следующие критерии применяются ко ВСЕМ задачам независимо от типа:

- [ ] Код соответствует стандартам кодирования (Go: golangci-lint, TS: ESLint)
- [ ] Код отформатирован (Go: `go fmt`, TS: Prettier)
- [ ] Нет комментариев TODO/FIXME без соответствующих issue
- [ ] Документация обновлена (если применимо)
- [ ] CHANGELOG.md обновлен (для user-facing изменений)
- [ ] Pull Request имеет понятное описание и связан с issue/задачей
- [ ] PR одобрен минимум одним reviewer'ом
- [ ] CI/CD pipeline проходит успешно
- [ ] Нет конфликтов с target branch

---

## 3. DoD для Backend Feature (Go)

### 3.1. Код и архитектура

- [ ] Функциональность реализована согласно требованиям
- [ ] Код следует архитектуре (handler → service → repository)
- [ ] Интерфейсы определены для ключевых компонентов
- [ ] Зависимости инжектируются через конструкторы
- [ ] Обработка ошибок корректна и использует wrap errors
- [ ] Нет hardcoded значений (все в конфигурации или константах)

### 3.2. Тестирование

- [ ] Unit тесты написаны для всех public функций
- [ ] Code coverage >= 80% для нового кода
- [ ] Integration тесты написаны для API endpoints
- [ ] Тесты проходят локально (`make test`)
- [ ] Тесты проходят в CI
- [ ] Моки созданы для внешних зависимостей
- [ ] Edge cases и error paths покрыты тестами

### 3.3. API и контракты

- [ ] API соответствует спецификации в `api-contracts.md`
- [ ] Request/Response валидация реализована
- [ ] HTTP статус коды корректны
- [ ] Формат ошибок соответствует стандарту
- [ ] OpenAPI спецификация обновлена (если применимо)

### 3.4. Безопасность

- [ ] Input sanitization реализована
- [ ] SQL injection предотвращен (используются prepared statements)
- [ ] XSS предотвращен
- [ ] Rate limiting применен (если требуется)
- [ ] Sensitive данные не логируются

### 3.5. Observability

- [ ] Структурное логирование реализовано
- [ ] Request ID передается через контекст
- [ ] Prometheus метрики экспортируются
- [ ] OpenTelemetry spans добавлены (если применимо)

### 3.6. Документация

- [ ] Godoc комментарии для public API
- [ ] README обновлен с примерами использования
- [ ] API документация обновлена

### 3.7. Deployment

- [ ] Миграции БД созданы и протестированы (если применимо)
- [ ] Environment переменные документированы
- [ ] Kustomize манифесты обновлены (если требуется)

---

## 4. DoD для Frontend Feature (React/TypeScript)

### 4.1. Код и архитектура

- [ ] Функциональность реализована согласно требованиям
- [ ] Компоненты разбиты на переиспользуемые части
- [ ] TypeScript типы определены (нет `any` без обоснования)
- [ ] React hooks используются корректно (нет warning'ов)
- [ ] State management реализован правильно
- [ ] Нет console.log в production коде

### 4.2. Тестирование

- [ ] Unit тесты написаны для компонентов (Testing Library)
- [ ] Code coverage >= 70% для нового кода
- [ ] API client тесты написаны (MSW)
- [ ] Тесты проходят локально (`npm test`)
- [ ] Тесты проходят в CI
- [ ] Accessibility тесты пройдены (axe/eslint-plugin-jsx-a11y)

### 4.3. UI/UX

- [ ] UI соответствует дизайну (если есть mockups)
- [ ] Responsive design работает на мобильных устройствах
- [ ] Loading states реализованы
- [ ] Error states реализованы
- [ ] Empty states реализованы
- [ ] Accessibility требования выполнены (ARIA, keyboard navigation)

### 4.4. Performance

- [ ] Нет ненужных re-renders (проверено React DevTools)
- [ ] Lazy loading применен для больших компонентов
- [ ] Images оптимизированы
- [ ] Bundle size не увеличился значительно

### 4.5. Интеграция с Backend

- [ ] API интеграция протестирована
- [ ] Error handling реализован
- [ ] API типы синхронизированы с backend

### 4.6. Документация

- [ ] Storybook stories созданы (если применимо)
- [ ] JSDoc комментарии для сложной логики
- [ ] README обновлен с примерами использования

---

## 5. DoD для Bug Fix

### 5.1. Исправление

- [ ] Root cause бага идентифицирована
- [ ] Фикс реализован и протестирован
- [ ] Regression тесты добавлены для предотвращения повторения
- [ ] Связанные баги проверены (нет аналогичных проблем)

### 5.2. Тестирование

- [ ] Баг воспроизведен локально до фикса
- [ ] Фикс проверен локально
- [ ] Unit тесты добавлены для бага
- [ ] Integration тесты добавлены (если применимо)
- [ ] Тесты проходят в CI

### 5.3. Документация

- [ ] Bug description и solution документированы в PR
- [ ] Если баг в API, документация обновлена

---

## 6. DoD для Infrastructure/Platform Task

### 6.1. Реализация

- [ ] Изменения инфраструктуры документированы
- [ ] Terraform/Kubernetes манифесты версионированы
- [ ] Dry-run выполнен в staging окружении
- [ ] Rollback план документирован

### 6.2. Тестирование

- [ ] Изменения протестированы в dev/staging
- [ ] Smoke тесты пройдены
- [ ] Performance тесты пройдены (если применимо)
- [ ] Security scan пройден

### 6.3. Документация

- [ ] Runbook обновлен
- [ ] Architecture diagrams обновлены
- [ ] Operational procedures документированы

### 6.4. Observability

- [ ] Мониторинг настроен
- [ ] Алерты настроены
- [ ] Dashboards созданы/обновлены
- [ ] Логирование настроено

### 6.5. Security

- [ ] Security review пройден
- [ ] Secrets управляются через Vault/SOPS
- [ ] Access control настроен
- [ ] Compliance требования выполнены

---

## 7. DoD для Documentation Task

### 7.1. Содержание

- [ ] Документация полная и точная
- [ ] Примеры кода работают
- [ ] Ссылки валидны
- [ ] Диаграммы актуальны

### 7.2. Формат

- [ ] Markdown правильно отформатирован
- [ ] Структура документа логична
- [ ] Навигация работает
- [ ] Статус документа указан (Draft/In Review/Approved)

### 7.3. Review

- [ ] Документация отревьюена SME (Subject Matter Expert)
- [ ] Technical accuracy проверена
- [ ] Grammar/spelling проверены

---

## 8. DoD для CI/CD Pipeline Change

### 8.1. Реализация

- [ ] Pipeline конфигурация версионирована
- [ ] Pipeline тестирован в feature branch
- [ ] Rollback механизм есть
- [ ] Pipeline идемпотентен

### 8.2. Тестирование

- [ ] Pipeline успешно выполнен минимум 3 раза
- [ ] Все stages пройдены
- [ ] Artifacts корректно созданы
- [ ] Deployment в staging успешен

### 8.3. Документация

- [ ] Pipeline документирован в `ci-cd-pipeline.md`
- [ ] Troubleshooting guide обновлен
- [ ] Required secrets документированы

### 8.4. Security

- [ ] Secrets не hardcoded
- [ ] Image signing настроен (если применимо)
- [ ] Security scanning включен

---

## 9. DoD для Database Migration

### 9.1. Миграция

- [ ] Migration script написан
- [ ] Rollback script написан
- [ ] Migration протестирован на копии production данных
- [ ] Performance impact оценен

### 9.2. Тестирование

- [ ] Migration успешно выполнен в dev
- [ ] Migration успешно выполнен в staging
- [ ] Rollback протестирован
- [ ] Data integrity проверена

### 9.3. Документация

- [ ] Migration plan документирован
- [ ] Rollback plan документирован
- [ ] Downtime (если есть) коммуницирован

### 9.4. Deployment

- [ ] Maintenance window запланирован (если требуется)
- [ ] Backup создан перед миграцией
- [ ] Monitoring настроен

---

## 10. DoD для Release

### 10.1. Code Quality

- [ ] Все критерии DoD для features выполнены
- [ ] Code freeze соблюден
- [ ] Нет open critical/blocker bugs
- [ ] Security scan пройден

### 10.2. Тестирование

- [ ] Full regression test suite пройден
- [ ] E2E тесты пройдены
- [ ] Performance тесты пройдены
- [ ] Security тесты пройдены
- [ ] UAT (User Acceptance Testing) пройден

### 10.3. Документация

- [ ] Release notes подготовлены
- [ ] CHANGELOG обновлен
- [ ] User documentation обновлена
- [ ] Migration guide подготовлен (если есть breaking changes)

### 10.4. Deployment

- [ ] Deployment plan документирован
- [ ] Rollback plan документирован
- [ ] Deployment успешен в staging
- [ ] Smoke тесты пройдены в staging
- [ ] Production deployment plan одобрен

### 10.5. Communication

- [ ] Stakeholders уведомлены
- [ ] Users уведомлены (если требуется)
- [ ] Support team проинформирован

---

## 11. Процесс проверки DoD

### 11.1. Self-Check

Перед созданием Pull Request разработчик обязан:
1. Пройти по чеклисту DoD для своего типа задачи
2. Отметить выполненные пункты в описании PR
3. Добавить комментарии для невыполненных пунктов (с обоснованием)

### 11.2. Code Review

Reviewer обязан:
1. Проверить что DoD чеклист заполнен
2. Валидировать выполнение критичных пунктов
3. Запросить изменения если DoD не выполнен
4. Не approve PR если DoD критерии не выполнены

### 11.3. Исключения

Исключения из DoD возможны только в следующих случаях:
- Hotfix критического бага в production (упрощенный DoD)
- Prototype/Spike (DoD определяется в описании задачи)
- Исключение одобрено Tech Lead'ом (с документацией причин)

---

## 12. DoD Metrics

Для улучшения процесса отслеживаем:

- **DoD Compliance Rate:** % PR с полностью выполненным DoD
- **Common Violations:** Наиболее часто пропускаемые критерии
- **Time to DoD:** Среднее время выполнения DoD после code complete
- **Rework Rate:** % PR требующих доработки из-за DoD

**Цель:** DoD Compliance Rate >= 95%

---

## 13. Template для Pull Request Description

```markdown
## Description
[Краткое описание изменений]

## Type of Change
- [ ] Bug fix
- [ ] New feature (Backend)
- [ ] New feature (Frontend)
- [ ] Infrastructure/Platform
- [ ] Documentation
- [ ] Other

## Definition of Done Checklist

### General
- [ ] Код соответствует стандартам кодирования
- [ ] Код отформатирован
- [ ] Нет TODO/FIXME без issue
- [ ] Документация обновлена
- [ ] CI/CD pipeline проходит

### Testing
- [ ] Unit тесты написаны и проходят
- [ ] Integration тесты написаны (если применимо)
- [ ] Code coverage >= 80% (backend) / 70% (frontend)
- [ ] Тесты проходят локально
- [ ] Тесты проходят в CI

### Code Quality
- [ ] Code review пройден
- [ ] Нет hardcoded значений
- [ ] Error handling реализован
- [ ] Logging добавлен

### [Добавьте специфичные для типа задачи критерии]
- [ ] ...

## Testing Evidence
[Скриншоты, логи, или описание проведенного тестирования]

## Related Issues
Closes #[issue number]

## Notes for Reviewers
[Дополнительная информация для reviewer'ов]
```

---

## 14. Связанные документы

- [API-контракты и спецификации](api-contracts.md)
- [Спецификация тестирования](testing-specification.md)
- [CI/CD Pipeline](ci-cd-pipeline.md)
- [Руководство по Doc-Driven Development](doc-driven-development.md)
- [Примеры референсной реализации](implementation-examples.md)

---

## 15. Обновления документа

| Дата       | Версия | Автор | Изменения |
|------------|--------|-------|-----------|
| 2025-10-23 | 1.0    | Claude | Первая версия DoD |
