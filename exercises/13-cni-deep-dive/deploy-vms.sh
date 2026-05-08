#!/bin/bash
# Deploy 3 Ubuntu VMs for kubeadm-based Kubernetes cluster (no CNI installed)
set -euo pipefail

RG="${1:-ckne-cni-lab}"
LOCATION="${2:-swedencentral}"
SSH_KEY="${3:-$HOME/.ssh/id_rsa.pub}"

if [ ! -f "$SSH_KEY" ]; then
  echo "SSH public key not found at $SSH_KEY"
  echo "Usage: $0 [resource-group] [location] [ssh-public-key-path]"
  exit 1
fi

SSH_PUB=$(cat "$SSH_KEY")

echo "==> Creating resource group $RG in $LOCATION..."
az group create --name "$RG" --location "$LOCATION" --output none

echo "==> Deploying 3 VMs (1 control-plane + 2 workers)..."
az deployment group create \
  --resource-group "$RG" \
  --template-file "$(dirname "$0")/kubeadm-cluster.bicep" \
  --parameters sshPublicKey="$SSH_PUB" \
  --output none

echo "==> Retrieving VM IPs..."
CP_IP=$(az deployment group show --resource-group "$RG" --name kubeadm-cluster --query 'properties.outputs.controlPlanePublicIP.value' -o tsv)
CP_PRIV=$(az deployment group show --resource-group "$RG" --name kubeadm-cluster --query 'properties.outputs.controlPlanePrivateIP.value' -o tsv)
W1_IP=$(az deployment group show --resource-group "$RG" --name kubeadm-cluster --query 'properties.outputs.worker1PublicIP.value' -o tsv)
W2_IP=$(az deployment group show --resource-group "$RG" --name kubeadm-cluster --query 'properties.outputs.worker2PublicIP.value' -o tsv)

echo ""
echo "============================================"
echo " VMs are deploying (cloud-init takes ~3-5 min)"
echo "============================================"
echo ""
echo "Control Plane:  ssh azureuser@$CP_IP  (private: $CP_PRIV)"
echo "Worker 1:       ssh azureuser@$W1_IP"
echo "Worker 2:       ssh azureuser@$W2_IP"
echo ""
echo "Wait for cloud-init to finish, then on the control plane run:"
echo "  sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$CP_PRIV"
echo ""
echo "To clean up:  az group delete --name $RG --yes --no-wait"
