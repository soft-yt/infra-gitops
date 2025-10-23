# Руководство по GitOps-операциям

**Статус документа:** Draft · **Аудитория:** платформа/SRE.

## 1. Структура репозитория (`infra-gitops`)
```
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
        └── overlays/
            ├── dev/
            ├── staging/ (план)
            └── prod/
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

## 3. Правила для окружений
- Overlays описывают теги образов, реплики, ingress-хосты, аннотации для Vault.
- Лейблы кластеров (`cloud=yc|sber|vk|onprem`, `env=dev|prod`) управляют много-кластерным флоу.
- Секреты хранятся в SOPS (`*.enc.yaml`) и расшифровываются при деплое через Argo CD plugin или Kustomize hook.

## 4. Операционные действия
- **Bootstrap:** установить Argo CD, применить ApplicationSet, зарегистрировать доступ к кластеру.
- **Промоушен:** смержить GitOps-PR с обновлёнными тегами или конфигурацией; Argo CD синхронизирует автоматически.
- **Rollback:** откатить коммит в `infra-gitops` и проконтролировать историю синхронизаций Argo CD.
- **Дрифт:** включить `selfHeal` и настроить алерты Argo CD → Grafana/Alertmanager.

## 5. Безопасность и комплаенс
- Ограничивать namespace’ы через Argo CD Projects (repo/path whitelists).
- Включить ImagePolicy и Cosign, чтобы пропускать только подписанные образы.
- Вести журнал: подключить Argo CD Notifications к Slack/Teams на события sync/fail/rollback.

## 6. Открытые вопросы
- Настроить окна синхронизации для продового окружения (например, рабочие часы).
- Определить правила ручных sync при критических изменениях (ingress, секреты).
- Выбрать инструмент для секретов (Argo CD Vault Plugin или External Secrets Operator).
