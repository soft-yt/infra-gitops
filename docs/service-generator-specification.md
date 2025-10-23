# Спецификация генератора сервисов

**Статус документа:** Draft · **Аудитория:** платформенная команда, разработчики.

## 1. Обзор

Генератор сервисов — CLI-инструмент и/или Backstage template для автоматизации создания новых микросервисов на платформе `soft-yt`. Инструмент создает репозиторий из шаблона, настраивает CI/CD и регистрирует сервис в GitOps.

## 2. Требования

### 2.1. Functional Requirements

**FR-001:** Генератор должен создавать репозиторий из шаблона `app-base-go-react`
**FR-002:** Генератор должен поддерживать параметризацию (имя сервиса, команда-владелец, описание)
**FR-003:** Генератор должен автоматически создавать GitHub репозиторий
**FR-004:** Генератор должен настраивать CI/CD (GitHub Actions workflow)
**FR-005:** Генератор должен создавать PR в `infra-gitops` для регистрации сервиса
**FR-006:** Генератор должен поддерживать dry-run режим (без создания ресурсов)
**FR-007:** Генератор должен валидировать входные параметры перед созданием
**FR-008:** Генератор должен поддерживать множественные шаблоны (Go+React, Python, Java)
**FR-009:** Генератор должен логировать все действия для аудита
**FR-010:** Генератор должен поддерживать откат в случае ошибки

### 2.2. Non-Functional Requirements

**NFR-001:** Время генерации сервиса < 3 минут
**NFR-002:** Инструмент работает на Linux, macOS, Windows
**NFR-003:** Понятные сообщения об ошибках с предложениями решений
**NFR-004:** Документация покрывает все use cases
**NFR-005:** Поддержка неинтерактивного режима (для CI/CD)

---

## 3. CLI Интерфейс

### 3.1. Команды

#### 3.1.1. `service create`

**Назначение:** Создание нового сервиса из шаблона.

**Синтаксис:**
```bash
soft-yt service create [flags]
```

**Обязательные флаги:**
- `--name` или `-n` (string) — имя сервиса (kebab-case, 3-50 символов)
- `--template` или `-t` (string) — шаблон (go-react, python-fastapi, java-spring)

**Опциональные флаги:**
- `--description` или `-d` (string) — описание сервиса (по умолчанию: "")
- `--owner` или `-o` (string) — команда-владелец (по умолчанию: текущий пользователь)
- `--org` (string) — GitHub организация (по умолчанию: soft-yt)
- `--visibility` (string) — видимость репозитория: public/private (по умолчанию: private)
- `--skip-ci` (bool) — пропустить настройку CI (по умолчанию: false)
- `--skip-gitops` (bool) — пропустить создание GitOps PR (по умолчанию: false)
- `--dry-run` (bool) — режим без создания реальных ресурсов (по умолчанию: false)
- `--interactive` или `-i` (bool) — интерактивный режим с промптами (по умолчанию: true)

**Примеры использования:**

```bash
# Интерактивный режим
soft-yt service create

# С параметрами
soft-yt service create --name my-awesome-service --template go-react --owner platform-team

# Dry-run для проверки
soft-yt service create -n test-service -t go-react --dry-run

# Неинтерактивный режим (для CI/CD)
soft-yt service create -n automated-service -t go-react -o devops-team --interactive=false
```

**Успешный вывод:**
```
🎯 Creating service: my-awesome-service
✓ Validating parameters...
✓ Creating GitHub repository: soft-yt/my-awesome-service
✓ Generating code from template: go-react
✓ Configuring CI/CD workflow
✓ Pushing initial commit
✓ Creating GitOps PR: infra-gitops#123
✓ Service created successfully!

📦 Repository: https://github.com/soft-yt/my-awesome-service
🔀 GitOps PR: https://github.com/soft-yt/infra-gitops/pull/123

Next steps:
  1. Review and merge GitOps PR to deploy to dev environment
  2. Clone repository: git clone git@github.com:soft-yt/my-awesome-service.git
  3. Start developing: cd my-awesome-service && make dev

⏱ Completed in 2m 34s
```

**Ошибочный вывод:**
```
❌ Error creating service: my-awesome-service

Validation errors:
  • name: must be lowercase and kebab-case (got "MyAwesomeService")
  • template: unsupported template "nodejs" (available: go-react, python-fastapi, java-spring)

Run with --help for usage information.
```

---

#### 3.1.2. `service list`

**Назначение:** Список всех созданных сервисов.

**Синтаксис:**
```bash
soft-yt service list [flags]
```

**Флаги:**
- `--owner` (string) — фильтр по владельцу
- `--template` (string) — фильтр по типу шаблона
- `--output` или `-o` (string) — формат вывода: table/json/yaml (по умолчанию: table)

**Пример:**
```bash
soft-yt service list --owner platform-team

NAME                  OWNER           TEMPLATE     CREATED         REPOSITORY
my-awesome-service    platform-team   go-react     2025-10-20      soft-yt/my-awesome-service
another-service       platform-team   python       2025-10-18      soft-yt/another-service
```

---

#### 3.1.3. `service validate`

**Назначение:** Валидация параметров без создания ресурсов.

**Синтаксис:**
```bash
soft-yt service validate [flags]
```

**Флаги:** те же что и для `service create`

**Пример:**
```bash
soft-yt service validate -n my-service -t go-react

✓ All parameters are valid
  • Name: my-service (valid kebab-case)
  • Template: go-react (available)
  • Owner: current-user (valid GitHub user)
  • Organization: soft-yt (accessible)
```

---

#### 3.1.4. `template list`

**Назначение:** Список доступных шаблонов.

**Синтаксис:**
```bash
soft-yt template list [flags]
```

**Флаги:**
- `--output` или `-o` (string) — формат вывода: table/json/yaml

**Пример:**
```bash
soft-yt template list

NAME              DESCRIPTION                           VERSION
go-react          Go backend + React frontend           1.0.0
python-fastapi    Python FastAPI service                1.0.0
java-spring       Java Spring Boot service              1.0.0
```

---

#### 3.1.5. `template show`

**Назначение:** Детальная информация о шаблоне.

**Синтаксис:**
```bash
soft-yt template show <template-name>
```

**Пример:**
```bash
soft-yt template show go-react

Template: go-react
Version: 1.0.0
Description: Monorepo with Go backend (chi router) and React frontend (Vite)

Stack:
  Backend:
    • Go 1.22+
    • chi router
    • PostgreSQL (optional)
    • OpenTelemetry
  Frontend:
    • React 18
    • TypeScript
    • Vite
    • Tailwind CSS (optional)

Structure:
  backend/       - Go API service
  frontend/      - React SPA
  deploy/        - Kubernetes manifests (Kustomize)
  .github/       - CI/CD workflows

Parameters:
  --enable-db         Enable PostgreSQL integration
  --enable-auth       Enable authentication middleware
  --enable-metrics    Enable Prometheus metrics (default: true)

Documentation: https://docs.soft-yt.com/templates/go-react
```

---

### 3.2. Глобальные флаги

```bash
--help, -h           Show help
--version, -v        Show version
--config             Path to config file (default: ~/.soft-yt/config.yaml)
--log-level          Log level: debug/info/warn/error (default: info)
--no-color           Disable colored output
```

---

## 4. Интерактивный режим

Если команда запущена без обязательных параметров, генератор входит в интерактивный режим:

```bash
$ soft-yt service create

🚀 Create a new service

? Service name: › my-awesome-service
? Description (optional): › My awesome microservice
? Select template: ›
  ❯ go-react (Go backend + React frontend)
    python-fastapi (Python FastAPI service)
    java-spring (Java Spring Boot service)
? Owner team: › platform-team
? GitHub organization: › soft-yt
? Repository visibility: ›
  ❯ Private
    Public

📋 Review your choices:
  Name:         my-awesome-service
  Template:     go-react
  Owner:        platform-team
  Organization: soft-yt
  Visibility:   private

? Confirm and create? (y/N) › y

Creating service...
```

---

## 5. Конфигурационный файл

**Location:** `~/.soft-yt/config.yaml`

```yaml
# GitHub configuration
github:
  org: soft-yt
  token: ghp_xxxxxxxxxxxxx  # или через GITHUB_TOKEN env var
  default_visibility: private

# GitOps configuration
gitops:
  repo: soft-yt/infra-gitops
  branch: main
  auto_merge: false  # автоматический merge PR

# Defaults
defaults:
  owner: platform-team
  template: go-react

# Templates
templates:
  - name: go-react
    repo: soft-yt/app-base-go-react
    version: v1.0.0
  - name: python-fastapi
    repo: soft-yt/app-base-python-fastapi
    version: v1.0.0

# Logging
log_level: info
log_file: ~/.soft-yt/logs/generator.log
```

---

## 6. Backstage Integration

### 6.1. Software Template

**Location:** `templates/service-template.yaml`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: go-react-service
  title: Go + React Service
  description: Create a new microservice with Go backend and React frontend
  tags:
    - go
    - react
    - microservice
spec:
  owner: platform-team
  type: service

  parameters:
    - title: Service Information
      required:
        - name
        - owner
      properties:
        name:
          title: Service Name
          type: string
          description: Name of the service (kebab-case)
          pattern: '^[a-z][a-z0-9-]*[a-z0-9]$'
          minLength: 3
          maxLength: 50
          ui:autofocus: true
          ui:help: Use lowercase letters, numbers, and hyphens only

        description:
          title: Description
          type: string
          description: Short description of the service
          maxLength: 200

        owner:
          title: Owner Team
          type: string
          description: Team responsible for this service
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: Group

    - title: Template Configuration
      properties:
        enableDatabase:
          title: Enable PostgreSQL
          type: boolean
          default: false
          description: Include PostgreSQL database configuration

        enableAuth:
          title: Enable Authentication
          type: boolean
          default: false
          description: Include authentication middleware

        enableMetrics:
          title: Enable Metrics
          type: boolean
          default: true
          description: Include Prometheus metrics endpoint

    - title: Deployment Configuration
      properties:
        environments:
          title: Initial Environments
          type: array
          items:
            type: string
            enum:
              - dev
              - staging
              - prod
          default: ['dev']
          ui:widget: checkboxes

  steps:
    - id: fetch-template
      name: Fetch Template
      action: fetch:template
      input:
        url: https://github.com/soft-yt/app-base-go-react
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          enableDatabase: ${{ parameters.enableDatabase }}
          enableAuth: ${{ parameters.enableAuth }}
          enableMetrics: ${{ parameters.enableMetrics }}

    - id: publish-github
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts: ['github.com']
        description: ${{ parameters.description }}
        repoUrl: github.com?owner=soft-yt&repo=${{ parameters.name }}
        defaultBranch: main
        repoVisibility: private
        deleteBranchOnMerge: true
        protectDefaultBranch: true

    - id: create-gitops-pr
      name: Create GitOps PR
      action: github:pullRequest:create
      input:
        repoUrl: github.com?owner=soft-yt&repo=infra-gitops
        title: 'feat: add ${{ parameters.name }} service'
        description: |
          ## New Service: ${{ parameters.name }}

          **Owner:** ${{ parameters.owner }}
          **Description:** ${{ parameters.description }}

          This PR adds GitOps manifests for the new service.

          - [ ] Review manifests
          - [ ] Verify CI/CD configuration
          - [ ] Deploy to dev environment
        sourceBranch: add-${{ parameters.name }}
        targetBranch: main

    - id: register-component
      name: Register in Backstage
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish-github.output.repoContentsUrl }}
        catalogInfoPath: '/catalog-info.yaml'

  output:
    links:
      - title: Repository
        url: ${{ steps.publish-github.output.remoteUrl }}
      - title: GitOps PR
        url: ${{ steps.create-gitops-pr.output.pullRequestUrl }}
      - title: View in Backstage
        icon: dashboard
        url: /catalog/default/component/${{ parameters.name }}
```

---

## 7. Workflow Process

### 7.1. Пошаговый процесс генерации

**Шаг 1: Валидация параметров**
- Проверка формата имени (kebab-case)
- Проверка доступности имени репозитория
- Валидация владельца (существует ли team/user)
- Проверка прав доступа к GitHub организации

**Шаг 2: Создание репозитория**
- Клонирование шаблона
- Замена плейсхолдеров в коде:
  - `{{SERVICE_NAME}}` → actual name
  - `{{SERVICE_DESCRIPTION}}` → actual description
  - `{{OWNER}}` → actual owner
  - `{{GITHUB_ORG}}` → organization
- Генерация `catalog-info.yaml` для Backstage
- Настройка branch protection rules

**Шаг 3: Настройка CI/CD**
- Создание `.github/workflows/ci.yml`
- Настройка GitHub Secrets:
  - `GHCR_PAT` — для публикации образов
  - `INFRA_GITOPS_TOKEN` — для обновления GitOps
- Настройка GitHub Environments (dev, staging, prod)

**Шаг 4: Создание GitOps манифестов**
- Генерация base manifests в `infra-gitops/apps/{service}/base/`
- Создание overlays для выбранных окружений
- Генерация ApplicationSet для Argo CD

**Шаг 5: Создание GitOps PR**
- Создание feature branch в `infra-gitops`
- Коммит сгенерированных манифестов
- Создание Pull Request с описанием
- Назначение ревьюеров из платформенной команды

**Шаг 6: Initial commit**
- Commit всех изменений в новый репозиторий
- Push в main branch
- Создание initial tag `v0.1.0`

**Шаг 7: Регистрация в Backstage** (опционально)
- Регистрация `catalog-info.yaml`
- Создание entity в Backstage catalog

---

### 7.2. Откат в случае ошибки

Если генерация прерывается ошибкой, выполняется rollback:

```bash
❌ Error at step "Create GitOps PR": authentication failed

🔄 Rolling back changes:
  ✓ Deleted GitHub repository: soft-yt/my-service
  ✓ Deleted GitOps branch: add-my-service
  ✓ Cleaned up local files

Service creation aborted.
```

Опции отката:
- `--no-rollback` — не выполнять откат (для debugging)
- `--partial-rollback` — откатить только последний шаг

---

## 8. Template Structure

### 8.1. Плейсхолдеры в шаблоне

Шаблон использует следующие плейсхолдеры для замены:

```
{{SERVICE_NAME}}            - my-awesome-service
{{SERVICE_NAME_UPPER}}      - MY_AWESOME_SERVICE
{{SERVICE_NAME_CAMEL}}      - MyAwesomeService
{{SERVICE_DESCRIPTION}}     - Service description
{{OWNER}}                   - platform-team
{{GITHUB_ORG}}              - soft-yt
{{YEAR}}                    - 2025
{{AUTHOR}}                  - Generated by soft-yt CLI
```

### 8.2. Пример файла с плейсхолдерами

**backend/cmd/api/main.go:**
```go
package main

import (
    "log"
    "{{GITHUB_ORG}}/{{SERVICE_NAME}}/internal/config"
    "{{GITHUB_ORG}}/{{SERVICE_NAME}}/internal/http"
)

func main() {
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("Failed to load config: %v", err)
    }

    log.Printf("Starting {{SERVICE_NAME}} service...")

    server := http.NewServer(cfg)
    if err := server.Start(); err != nil {
        log.Fatalf("Server error: %v", err)
    }
}
```

**catalog-info.yaml:**
```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: {{SERVICE_NAME}}
  description: {{SERVICE_DESCRIPTION}}
  annotations:
    github.com/project-slug: {{GITHUB_ORG}}/{{SERVICE_NAME}}
spec:
  type: service
  owner: {{OWNER}}
  lifecycle: production
```

---

## 9. Acceptance Criteria

### 9.1. CLI Acceptance Criteria

- **AC-GEN-001:** CLI создает валидный репозиторий из шаблона за < 3 минут
- **AC-GEN-002:** Все плейсхолдеры заменяются корректными значениями
- **AC-GEN-003:** Сгенерированный код компилируется и проходит базовые тесты
- **AC-GEN-004:** CI/CD workflow успешно выполняется после первого коммита
- **AC-GEN-005:** GitOps PR создается с корректными манифестами
- **AC-GEN-006:** Dry-run режим не создает реальных ресурсов
- **AC-GEN-007:** Rollback полностью очищает созданные ресурсы
- **AC-GEN-008:** Интерактивный режим работает без сбоев
- **AC-GEN-009:** Валидация параметров отклоняет невалидные входные данные
- **AC-GEN-010:** CLI работает на Linux, macOS, Windows

### 9.2. Backstage Template Acceptance Criteria

- **AC-BST-001:** Template отображается в Backstage catalog
- **AC-BST-002:** Форма ввода параметров валидирует данные
- **AC-BST-003:** Template успешно генерирует репозиторий
- **AC-BST-004:** Сгенерированный сервис регистрируется в Backstage catalog
- **AC-BST-005:** Все шаги workflow выполняются без ошибок
- **AC-BST-006:** Output links ведут на корректные ресурсы

---

## 10. Test Scenarios

### 10.1. Unit Tests

**TS-GEN-001: Parameter Validation**
```go
func TestValidateServiceName(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"valid lowercase", "my-service", false},
        {"invalid uppercase", "MyService", true},
        {"invalid underscore", "my_service", true},
        {"too short", "ab", true},
        {"too long", strings.Repeat("a", 51), true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateServiceName(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateServiceName() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**TS-GEN-002: Placeholder Replacement**
```go
func TestReplacePlaceholders(t *testing.T) {
    template := "Service: {{SERVICE_NAME}}, Owner: {{OWNER}}"
    params := Params{
        ServiceName: "my-service",
        Owner:       "platform-team",
    }

    result := ReplacePlaceholders(template, params)
    expected := "Service: my-service, Owner: platform-team"

    assert.Equal(t, expected, result)
}
```

### 10.2. Integration Tests

**TS-GEN-003: End-to-End Service Generation**
```go
func TestGenerateService_EndToEnd(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    // Arrange
    params := ServiceParams{
        Name:        "test-service-" + randomString(6),
        Template:    "go-react",
        Owner:       "test-team",
        DryRun:      false,
        SkipGitOps:  true, // Skip GitOps for test
    }

    // Act
    result, err := GenerateService(params)

    // Assert
    assert.NoError(t, err)
    assert.NotEmpty(t, result.RepoURL)

    // Verify repository exists
    repo, err := githubClient.GetRepository(params.Name)
    assert.NoError(t, err)
    assert.Equal(t, params.Name, repo.Name)

    // Cleanup
    defer githubClient.DeleteRepository(params.Name)
}
```

---

## 11. Технический стек

### 11.1. CLI Implementation

**Language:** Go 1.22+

**Libraries:**
- `github.com/spf13/cobra` — CLI framework
- `github.com/spf13/viper` — конфигурация
- `github.com/google/go-github/v57` — GitHub API
- `github.com/AlecAivazis/survey/v2` — интерактивные промпты
- `github.com/fatih/color` — цветной вывод
- `gopkg.in/yaml.v3` — YAML parsing

**Structure:**
```
soft-yt-cli/
├── cmd/
│   ├── root.go
│   ├── service/
│   │   ├── create.go
│   │   ├── list.go
│   │   └── validate.go
│   └── template/
│       ├── list.go
│       └── show.go
├── internal/
│   ├── generator/
│   │   ├── generator.go
│   │   ├── template.go
│   │   └── placeholder.go
│   ├── github/
│   │   ├── client.go
│   │   └── repository.go
│   ├── gitops/
│   │   ├── pr.go
│   │   └── manifests.go
│   └── validator/
│       └── validator.go
├── pkg/
│   └── models/
│       └── service.go
├── templates/
│   └── go-react/
└── main.go
```

---

## 12. Документация

### 12.1. Пользовательская документация

**Location:** `/docs/user-guide/service-generator.md`

Разделы:
- Установка CLI
- Быстрый старт
- Детальное описание команд
- Конфигурация
- Troubleshooting
- FAQ

### 12.2. Документация для разработчиков шаблонов

**Location:** `/docs/developer-guide/creating-templates.md`

Разделы:
- Структура шаблона
- Плейсхолдеры и их использование
- Тестирование шаблонов
- Публикация шаблонов
- Best practices

---

## 13. Метрики и мониторинг

### 13.1. Usage Metrics

Собираем метрики (с согласия пользователя):
- Количество созданных сервисов
- Распределение по шаблонам
- Среднее время генерации
- Процент ошибок
- Популярные опции

### 13.2. Error Tracking

Интеграция с Sentry/OpenTelemetry для отслеживания ошибок.

---

## 14. Открытые вопросы

- Нужна ли поддержка обновления существующих сервисов из новой версии шаблона?
- Как обрабатывать кастомизацию шаблонов (hooks, scripts)?
- Требуется ли поддержка private templates?
- Нужна ли интеграция с JIRA для автоматического создания эпиков?
- Как реализовать multi-service generation (создание нескольких связанных сервисов)?

---

## 15. Связанные документы

- [Шаблон сервиса: app-base-go-react](service-template-app-base-go-react.md)
- [CI/CD Pipeline](ci-cd-pipeline.md)
- [GitOps Operations](gitops-operations.md)
- [API Contracts](api-contracts.md)
- [Testing Specification](testing-specification.md)
