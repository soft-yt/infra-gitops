# Traefik Ingress Controller

**Version:** v3.5.3
**Status:** ✅ Deployed
**Namespace:** traefik

## Overview

Traefik is deployed as the default ingress controller for the `soft-yt-dev` Kubernetes cluster.

## Details

**LoadBalancer External IP:** `158.160.198.44`

**Service:**
```bash
kubectl get svc -n traefik traefik
```

**Endpoints:**
- HTTP: Port 80
- HTTPS: Port 443

## Installation

Traefik was installed using Helm:

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update

helm install traefik traefik/traefik \
  --namespace traefik \
  --set service.type=LoadBalancer \
  --set ports.web.port=80 \
  --set ports.websecure.port=443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=true
```

## Ingress Resources

### Argo CD
- **Host:** argocd.dev.tulupov.org
- **Config:** [argocd-ingress.yaml](./argocd-ingress.yaml)
- **TLS:** Enabled (currently using Argo CD's self-signed cert)

## DNS Configuration

See [DNS-SETUP.md](./DNS-SETUP.md) for DNS configuration instructions.

All `*.dev.tulupov.org` domains should point to: `158.160.198.44`

## Useful Commands

### Check Traefik Status
```bash
kubectl get pods -n traefik
kubectl get svc -n traefik
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### List All Ingress Resources
```bash
kubectl get ingress -A
```

### View Ingress Details
```bash
kubectl describe ingress argocd-server-ingress -n argocd
```

## Future Enhancements

1. **cert-manager Integration**
   - Automatic TLS certificates from Let's Encrypt
   - No more self-signed certificate warnings

2. **Additional Ingress Resources**
   - Grafana: `grafana.dev.tulupov.org`
   - Prometheus: `prometheus.dev.tulupov.org`
   - Application endpoints

3. **Traefik Dashboard**
   - Enable Traefik web UI for monitoring
   - Expose at `traefik.dev.tulupov.org`

## Troubleshooting

### LoadBalancer Stuck in Pending
```bash
# Check service events
kubectl describe svc traefik -n traefik

# Verify service account has load-balancer.admin role
yc iam service-account list-access-bindings aje1sjcpj9sgaaup1iid
```

### Ingress Not Working
```bash
# Check Ingress status
kubectl get ingress -n argocd
kubectl describe ingress argocd-server-ingress -n argocd

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f
```

### TLS Certificate Issues
```bash
# Check TLS secret exists
kubectl get secret argocd-server-tls -n argocd

# View certificate details
kubectl get secret argocd-server-tls -n argocd -o yaml
```

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Traefik Kubernetes Ingress](https://doc.traefik.io/traefik/routing/providers/kubernetes-ingress/)
- [Helm Chart Values](https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml)
