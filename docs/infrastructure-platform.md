# Инфраструктура и платформенные сервисы

**Статус документа:** Active · **Аудитория:** платформенные инженеры и SRE.
**Последнее обновление:** 2025-10-24

## 1. Кластеры Kubernetes

### 1.1. Обзор

Платформа использует мультиоблачную стратегию с кластерами в разных провайдерах:
- **Yandex Cloud** - dev/staging окружения
- **SberCloud** - production (планируется)
- **VK Cloud** - production (планируется)
- **On-premise** - lab/тестирование (планируется)

### 1.2. Yandex Cloud - Dev Cluster

**Статус:** ⏳ PROVISIONING (создан 2025-10-24)

**Конфигурация:**
- **Имя:** `soft-yt-dev`
- **ID:** `catov23ueu3ol6a8h4v9`
- **Cloud:** `soft-yt` (b1gqfvm7sq54emnjt1lg)
- **Folder:** `default` (b1g5rh822asfv4vchtci)
- **Регион:** `ru-central1`
- **Зона:** `ru-central1-a`
- **Kubernetes версия:** 1.31 (regular channel)

**Сеть:**
- VPC: `default` (enpnr88d2ko4g958rk1i)
- Subnet: `10.128.0.0/24` (ru-central1-a)
- Pod CIDR: `10.96.0.0/16`
- Service CIDR: `10.112.0.0/16`

**API Endpoints:**
- External: `https://84.201.175.42`
- Internal: `https://10.128.0.23`

**Service Accounts:**
- Cluster SA: `k8s-cluster-sa` (aje1sjcpj9sgaaup1iid)
  - Роли: `k8s.clusters.agent`, `vpc.publicAdmin`, `container-registry.images.puller`
- Node SA: `k8s-node-sa` (ajed2vhe6ac90fsgljvm)
  - Роли: `container-registry.images.puller`

**Node Group** (планируется):
- Платформа: Intel Ice Lake (standard-v2)
- Количество нод: 3 (для HA)
- Ресурсы: 2 vCPU, 4 GB RAM на ноду
- Диск: 30 GB SSD
- Preemptible: Да (экономия затрат)

**Документация:** [clusters/yc-dev/cluster-info/README.md](../clusters/yc-dev/cluster-info/README.md)

**Automation:**
- Node group: `clusters/yc-dev/create-node-group.sh`
- Argo CD: `clusters/yc-dev/argo-cd/install.sh`

### 1.3. Стандартная конфигурация кластера

На каждом кластере развернуты:
- **Argo CD** (namespaced), доступ ограничен через RBAC
- **Стек наблюдаемости** (Prometheus, Grafana, Loki, Tempo) через Helm
- **Ingress Controller** (Traefik - выбран для Phase 2)
- **cert-manager** для управления TLS сертификатами
- **ExternalDNS** для автоматического управления DNS

## 2. Сеть и маршрутизация
- ExternalDNS управляет DNS-записями по окружениям (пример: `dev.localhost`, `prod.company.ru`).
- TLS выдаётся через cert-manager: Let’s Encrypt в облаке, кастомный CA on-prem.
- Стратегия ingress определяется overlay (Istio Gateway против Traefik).

## 3. Управление секретами
- **SOPS (age):** шифрует GitOps-манифесты в `infra-gitops` (`*.enc.yaml`).
- **Vault:** выдаёт рантайм-секреты через Kubernetes auth или CSI driver; путь монтирования описывать в сервисных доках.
- Ключи шифрования хранить отдельно (KMS или аппаратный модуль), менять раз в квартал.

## 4. Безопасность образов
- Конвейер сборки подписывает образы Cosign (`cosign sign ghcr.io/soft-yt/<image>`).
- Argo CD ImagePolicy проверяет подписи перед синхронизацией; неподписанные образы блокируются.
- Формировать SBOM (Syft/Grype) и публиковать в реестр для отслеживания зависимостей.

## 5. Наблюдаемость
- Prometheus снимает метрики backend/frontend; экспонировать `/metrics` в Go-сервисе, интегрировать браузерные метрики для фронтенда.
- Grafana дашборды версионировать в `docs/assets/grafana/` (JSON экспорт, ревью обязательно).
- Loki + Tempo собирают логи и трейсы; использовать OpenTelemetry SDK в коде.

## 6. Автоматизация платформы
- Внедрить Terraform/Crossplane для кластеров, DNS, реестров.
- Автоматизировать онбординг кластеров (регистрация в Argo CD, базовые манифесты).
- Стандартизировать backup/restore для Stateful-компонентов (Vault, Prometheus, Grafana).

## 7. Автоматизация и IaC

### 7.1. Yandex Cloud CLI

Все операции с YC выполняются через `yc` CLI:
```bash
# Конфигурация
yc config set cloud-id b1gqfvm7sq54emnjt1lg
yc config set folder-id b1g5rh822asfv4vchtci

# Создание кластера
yc managed-kubernetes cluster create \
  --name soft-yt-dev \
  --version 1.31 \
  --network-id enpnr88d2ko4g958rk1i \
  --zone ru-central1-a \
  --subnet-id e9blkt9v4tsaq8tvbhlk \
  --public-ip \
  --service-account-id aje1sjcpj9sgaaup1iid \
  --node-service-account-id ajed2vhe6ac90fsgljvm
```

### 7.2. kubectl Configuration

```bash
# Получить credentials
yc managed-kubernetes cluster get-credentials soft-yt-dev --external --force

# Проверить подключение
kubectl cluster-info
kubectl get nodes
```

### 7.3. Планируемые улучшения

- Terraform модули для создания кластеров
- Crossplane для управления облачными ресурсами
- Автоматический онбординг кластеров в Argo CD
- Backup/restore для stateful компонентов

## 8. Прогресс реализации

**Week 1 (2025-10-23):** ✅ ЗАВЕРШЕНО
- Multi-repo архитектура (app-base-go-react + infra-gitops)
- Phase 1: Clean Architecture, 73% coverage
- CI/CD pipeline с GHCR
- GitOps манифесты

**Week 2 (2025-10-24):** ⏳ В ПРОЦЕССЕ
- ✅ Yandex Cloud CLI настроен
- ✅ Service accounts с IAM ролями
- ⏳ Kubernetes cluster (создаётся)
- 🔜 Node group
- 🔜 Argo CD deployment
- 🔜 ApplicationSet для multi-cluster sync
- 🔜 Phase 2: Observability stack

## 9. Открытые вопросы

- Как делится ответственность между infra и app командами за mesh и наблюдаемость.
- Нужен ли централизованный policy engine (OPA/Gatekeeper) для ограничений по ресурсам и реестрам.
- Требования к мониторингу затрат и бюджетированию по каждому облаку.
- Стратегия multi-region для HA (ru-central1 vs другие регионы YC).
