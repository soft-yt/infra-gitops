# Observability Stack Deployment Report

**Date:** 2025-10-24
**Status:** ✅ COMPLETED
**Phase:** Week 2 - Phase 2.1 (Observability)

## Executive Summary

Successfully deployed complete observability stack with Prometheus, Grafana, and Alertmanager. All components running with persistence, accessible via HTTPS with Let's Encrypt certificates.

## Deployed Components

### 1. Prometheus

**Status:** ✅ RUNNING (2/2 pods)
**Version:** Latest (via kube-prometheus-stack)
**Configuration:**
- Retention: 7 days
- Storage: 10Gi persistent volume
- Scrape interval: Default (30s)
- Evaluation interval: Default (30s)

**Metrics Sources:**
- Kubernetes API server
- Kubelet metrics
- cAdvisor (container metrics)
- Node Exporter (node metrics - 3 instances)
- Kube State Metrics
- Prometheus itself

**Service:**
- ClusterIP: 10.112.250.251
- Port: 9090

### 2. Grafana

**Status:** ✅ RUNNING (3/3 pods)
**Version:** Latest (via kube-prometheus-stack)

**Access:**
- **URL:** https://grafana.dev.tulupov.org
- **Username:** admin
- **Password:** admin123
- **TLS Certificate:** ✅ Let's Encrypt (expires 2026-01-22)

**Configuration:**
- Persistence: Enabled (5Gi PVC)
- Data Source: Prometheus (pre-configured)
- Dashboards: Pre-installed (Kubernetes cluster monitoring)

**Pre-installed Dashboards:**
1. Kubernetes / Compute Resources / Cluster
2. Kubernetes / Compute Resources / Namespace (Pods)
3. Kubernetes / Compute Resources / Node (Pods)
4. Kubernetes / Compute Resources / Pod
5. Kubernetes / Networking / Cluster
6. Kubernetes / Networking / Namespace (Pods)
7. Node Exporter / Nodes
8. Prometheus / Overview
9. And many more...

### 3. Alertmanager

**Status:** ✅ RUNNING (2/2 pods)
**Version:** Latest (via kube-prometheus-stack)

**Configuration:**
- Replicas: 2 (HA)
- Service: ClusterIP 10.112.186.247:9093

**Pre-configured Alerts:**
- Watchdog (always firing - health check)
- CPU throttling alerts
- Memory alerts
- Disk alerts
- Node alerts
- Kubernetes component alerts

### 4. Node Exporters

**Status:** ✅ RUNNING (3/3 pods - one per node)

**Metrics Collected:**
- CPU usage
- Memory usage
- Disk I/O
- Network I/O
- Filesystem metrics
- Hardware metrics

**Nodes Monitored:**
1. cl1cjpog66o7us9m582p-ofuj
2. cl1cjpog66o7us9m582p-uqoj
3. cl1cjpog66o7us9m582p-ycet

### 5. Kube State Metrics

**Status:** ✅ RUNNING (1/1 pod)

**Metrics Provided:**
- Deployment status
- Pod status
- Node status
- PVC status
- ConfigMap/Secret metadata
- And more Kubernetes object states

### 6. Prometheus Operator

**Status:** ✅ RUNNING (1/1 pod)

**Purpose:** Manages Prometheus and Alertmanager instances via CRDs

## Networking

### Ingress Configuration

**Grafana Ingress:**
- Host: grafana.dev.tulupov.org
- TLS: Enabled (Let's Encrypt)
- Certificate Secret: grafana-dev-tulupov-org-tls
- Ingress Class: traefik

**Internal Services:**
All monitoring services use ClusterIP and are accessible within the cluster.

## Storage

**Persistent Volumes Created:**
1. **Prometheus Data:**
   - Size: 10Gi
   - StorageClass: default (Yandex Cloud)
   - Purpose: Metrics storage

2. **Grafana Data:**
   - Size: 5Gi
   - StorageClass: default (Yandex Cloud)
   - Purpose: Dashboards, users, settings

3. **Alertmanager Data:**
   - Size: Default
   - Purpose: Alert state persistence

## Verification

### Health Checks

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# All pods should be Running:
# - alertmanager-*: 2/2
# - prometheus-grafana-*: 3/3
# - prometheus-kube-prometheus-operator-*: 1/1
# - prometheus-kube-state-metrics-*: 1/1
# - prometheus-prometheus-*: 2/2
# - prometheus-prometheus-node-exporter-* (x3): 1/1
```

### Access Verification

```bash
# Grafana (external)
curl -I https://grafana.dev.tulupov.org
# Should return HTTP 200 OK with valid certificate

# Prometheus (internal)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Access at http://localhost:9090

# Alertmanager (internal)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Access at http://localhost:9093
```

## Pre-configured Metrics

The stack automatically collects:

**Cluster Metrics:**
- Node CPU/Memory/Disk usage
- Pod resource requests/limits
- Container restarts
- Network traffic

**Application Metrics:**
- HTTP request rates (if instrumented)
- Application-specific metrics (via ServiceMonitor)

**Kubernetes Metrics:**
- API server latency
- etcd performance
- Scheduler performance
- Controller manager metrics

## ServiceMonitor CRDs

The Prometheus Operator automatically discovers ServiceMonitors. To add monitoring for your application:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: dev
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
```

## AlertManager Configuration

**Current Setup:**
- Default configuration (logs alerts to pod)
- For production: Configure email/Slack/PagerDuty receivers

**To add receivers:**
```bash
kubectl edit secret -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager
```

## Next Steps

### Immediate
- [ ] Add custom Grafana dashboards for applications
- [ ] Configure AlertManager receivers (Slack/email)
- [ ] Create ServiceMonitors for deployed applications

### Phase 2.2 - Logging
- [ ] Deploy Loki for log aggregation
- [ ] Configure Promtail for log collection
- [ ] Add Loki data source to Grafana

### Phase 2.3 - Tracing
- [ ] Deploy Tempo for distributed tracing
- [ ] Configure OpenTelemetry collectors
- [ ] Add Tempo data source to Grafana

## Files Created

### Ingress Configuration
- `clusters/yc-dev/traefik/grafana-ingress.yaml` - Grafana HTTPS ingress

### ApplicationSet Fix
- `clusters/yc-dev/argo-cd/applicationset.yaml` - Fixed namespace templating

## Cost Estimate

**Storage Costs (Yandex Cloud):**
- Prometheus PV: 10Gi × ~$0.10/GB/month = $1.00/month
- Grafana PV: 5Gi × ~$0.10/GB/month = $0.50/month
- **Total Storage:** ~$1.50/month

**Compute Costs:**
- Included in node costs (no additional charge)

**Total Added Cost:** ~$1.50/month

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check ServiceMonitors
kubectl get servicemonitors -A

# Check Prometheus config
kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus -o yaml
```

### Grafana Login Issues

```bash
# Get admin password
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

### Certificate Not Renewing

```bash
# Check certificate status
kubectl describe certificate grafana-dev-tulupov-org-tls -n monitoring

# Force renewal (if within 30 days of expiry)
kubectl delete certificate grafana-dev-tulupov-org-tls -n monitoring
kubectl apply -f clusters/yc-dev/traefik/grafana-ingress.yaml
```

## References

- [Prometheus Operator Documentation](https://prometheus-operator.dev/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Documentation](https://grafana.com/docs/)

---

**Report Prepared:** 2025-10-24
**Platform Team:** Yaroslav Tulupov + Claude Code
**Next Phase:** Phase 2.2 (Logging - Loki)

🎉 **Observability Stack: SUCCESS!**
