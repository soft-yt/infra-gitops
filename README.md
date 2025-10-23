# infra-gitops

GitOps repository for Kubernetes deployments using Argo CD.

## Repository Structure

```
infra-gitops/
├── README.md
├── clusters/                   # Cluster configurations
│   ├── yc-dev/                 # Yandex Cloud Dev cluster
│   │   └── argo-cd/
│   │       └── applicationset.yaml
│   ├── vk-prod/                # VK Cloud Prod cluster
│   │   └── argo-cd/
│   └── onprem-lab/             # On-premise Lab cluster
│       └── argo-cd/
├── apps/                       # Application manifests
│   └── webapp/
│       ├── base/               # Kustomize base
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── configmap.yaml
│       │   └── kustomization.yaml
│       └── overlays/           # Environment-specific configs
│           └── dev/
│               ├── deployment-patch.yaml
│               ├── ingress.yaml
│               └── kustomization.yaml
├── secrets/                    # Encrypted secrets (SOPS)
│   ├── .sops.yaml
│   └── dev/
│       └── secrets.enc.yaml
└── docs/                       # Platform documentation
```

## Principles

This repository follows GitOps principles:

1. **Declarative Configuration**: All desired state is declared in Git
2. **Version Controlled**: Full audit trail of changes
3. **Automated Sync**: Argo CD automatically reconciles cluster state
4. **Multi-Cluster**: Supports multiple clouds (YC, VK, Sber) and on-premise

## Workflows

### Deploy New Application

1. Add application manifests to `apps/<app-name>/base/`
2. Create overlays for each environment in `apps/<app-name>/overlays/`
3. Argo CD ApplicationSet automatically discovers and deploys

### Update Application

1. Modify manifests or overlays
2. Commit and push to Git
3. Argo CD automatically syncs changes (if auto-sync enabled)

### Rollback

1. Revert Git commit
2. Argo CD syncs to previous state

## Multi-Cluster Setup

Applications are deployed across multiple clusters using Argo CD ApplicationSet:

- **yc-dev**: Development environment (Yandex Cloud)
- **vk-prod**: Production environment (VK Cloud)
- **onprem-lab**: Lab environment (On-premise)

## Security

- **Secrets**: Encrypted with SOPS (age)
- **Access Control**: Repository permissions control deployment access
- **Image Policy**: Only signed images (Cosign) allowed
- **RBAC**: Argo CD Projects restrict namespace access

## Related Repositories

- [app-base-go-react](https://github.com/soft-yt/app-base-go-react) - Service template (Go + React)
- Platform documentation is in `docs/` directory of this repository

## Quick Start

### Prerequisites

- Kubernetes cluster(s) running
- Argo CD installed
- Access to this Git repository

### Bootstrap Cluster

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply ApplicationSet
kubectl apply -f clusters/yc-dev/argo-cd/applicationset.yaml

# Watch deployments
kubectl get applications -n argocd
```

### View Applications

```bash
# Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login (default password is in secret)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Documentation

Full platform documentation is available in `docs/`:

- [Architecture Overview](docs/architecture-overview.md)
- [GitOps Operations Guide](docs/gitops-operations.md)
- [Service Template Guide](docs/service-template-app-base-go-react.md)
- [CI/CD Pipeline](docs/ci-cd-pipeline.md)
- [Implementation Roadmap](docs/implementation-roadmap.md)

## Support

For questions and support, please refer to the platform documentation or contact the platform team.
