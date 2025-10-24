# YC Dev Cluster Information

## Cluster Details

**Name:** `soft-yt-dev`
**Cloud:** `soft-yt` (b1gqfvm7sq54emnjt1lg)
**Folder:** `default` (b1g5rh822asfv4vchtci)
**Region:** `ru-central1`
**Zone:** `ru-central1-a`
**Kubernetes Version:** 1.31 (regular channel)

### Cluster ID
```
catov23ueu3ol6a8h4v9
```

### Network Configuration

**VPC Network:** `default` (enpnr88d2ko4g958rk1i)

**Subnets:**
- `ru-central1-a`: 10.128.0.0/24 (e9blkt9v4tsaq8tvbhlk) - **Cluster subnet**
- `ru-central1-b`: 10.129.0.0/24 (e2l4hg89idtbjrv5gjhc)
- `ru-central1-d`: 10.130.0.0/24 (fl86c5fge0raieoh4813)

**Cluster IP Ranges:**
- Pod CIDR: 10.96.0.0/16
- Service CIDR: 10.112.0.0/16

### Service Accounts

**Cluster Service Account:** `k8s-cluster-sa` (aje1sjcpj9sgaaup1iid)
- Roles:
  - `k8s.clusters.agent` - Manage cluster
  - `vpc.publicAdmin` - Manage public IPs
  - `container-registry.images.puller` - Pull container images

**Node Service Account:** `k8s-node-sa` (ajed2vhe6ac90fsgljvm)
- Roles:
  - `container-registry.images.puller` - Pull container images on nodes

### Public Access

**API Endpoint:** Public IP enabled (assigned after cluster creation)

## kubectl Configuration

Connect to cluster after creation:

```bash
# Get cluster credentials
yc managed-kubernetes cluster get-credentials soft-yt-dev \
  --external \
  --force

# Verify connection
kubectl cluster-info
kubectl get nodes
```

## Node Group Configuration

Node group will be created with:
- **Platform:** Intel Ice Lake
- **Nodes:** 3 (for HA)
- **Instance type:** 2 vCPU, 4 GB RAM
- **Disk:** 30 GB SSD
- **Auto-scaling:** Enabled (min: 1, max: 5)
- **Zones:** ru-central1-a

## Created

- **Date:** 2025-10-24
- **Operation ID:** catav2cnfge6vhp14mnk
- **Status:** Creating (5-10 minutes)

## Next Steps

After cluster creation:
1. Create node group
2. Configure kubectl
3. Deploy Argo CD
4. Configure ApplicationSet
5. Deploy observability stack (Phase 2)
