#!/bin/bash
#
# Install Argo CD in soft-yt-dev cluster
#

set -e

CLUSTER_NAME="soft-yt-dev"
ARGOCD_VERSION="v2.11.0"

echo "Installing Argo CD ${ARGOCD_VERSION} in ${CLUSTER_NAME}..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

echo "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server \
  deployment/argocd-repo-server \
  deployment/argocd-application-controller \
  -n argocd

echo "Argo CD installed successfully!"
echo ""
echo "Get initial admin password:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "Port-forward to access UI:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Access UI: https://localhost:8080"
echo "Username: admin"
