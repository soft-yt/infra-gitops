#!/bin/bash
#
# Script to create node group for soft-yt-dev cluster
#

set -e

CLUSTER_ID="catov23ueu3ol6a8h4v9"
NODE_SA_ID="ajed2vhe6ac90fsgljvm"
SUBNET_ID="e9blkt9v4tsaq8tvbhlk"  # ru-central1-a

echo "Creating node group for cluster ${CLUSTER_ID}..."

yc managed-kubernetes node-group create \
  --name soft-yt-dev-nodes \
  --cluster-id "${CLUSTER_ID}" \
  --platform standard-v2 \
  --cores 2 \
  --memory 4 \
  --core-fraction 100 \
  --disk-type network-ssd \
  --disk-size 30 \
  --fixed-size 3 \
  --location zone=ru-central1-a,subnet-id="${SUBNET_ID}" \
  --network-interface subnets=["${SUBNET_ID}"],ipv4-address=nat \
  --preemptible \
  --async

echo "Node group creation started (async operation)"
echo "Monitor status: yc managed-kubernetes node-group list --cluster-id ${CLUSTER_ID}"
