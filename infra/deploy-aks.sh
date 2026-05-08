#!/bin/bash
# ============================================================================
# Deploy shared AKS cluster for CKNE exercises
# ============================================================================
# Usage:
#   chmod +x deploy-aks.sh
#   ./deploy-aks.sh [resource-group-name] [location]
# ============================================================================

set -euo pipefail

RG="${1:-ckne-lab}"
LOCATION="${2:-swedencentral}"
CLUSTER_NAME="ckne-aks"

echo "==> Creating resource group: $RG in $LOCATION"
az group create --name "$RG" --location "$LOCATION" --output none

echo "==> Deploying AKS cluster: $CLUSTER_NAME"
az deployment group create \
  --resource-group "$RG" \
  --template-file "$(dirname "$0")/aks-cluster.bicep" \
  --parameters \
    clusterName="$CLUSTER_NAME" \
    location="$LOCATION" \
    networkPlugin=azure \
    networkPolicy=calico \
  --output none

echo "==> Fetching AKS credentials"
az aks get-credentials --resource-group "$RG" --name "$CLUSTER_NAME" --overwrite-existing

echo "==> Verifying cluster connectivity"
kubectl get nodes

echo ""
echo "✅ AKS cluster '$CLUSTER_NAME' is ready. You can now start the exercises."
