#!/bin/bash
# ============================================================================
# Exercise 13 — CNI Deep Dive: Verification Script
# ============================================================================
# This script SSHs into the control-plane VM to run kubectl checks.
# Usage: ./verify.sh [resource-group]
# ============================================================================
set -uo pipefail

RG="${1:-ckne-cni-lab}"
PASS=0; FAIL=0; BONUS_PASS=0; BONUS_FAIL=0

# Retrieve control-plane public IP
CP_IP=$(az deployment group show --resource-group "$RG" --name kubeadm-cluster \
  --query 'properties.outputs.controlPlanePublicIP.value' -o tsv 2>/dev/null)

if [[ -z "$CP_IP" ]]; then
  echo "❌ Could not find control-plane VM in resource group '$RG'."
  echo "   Usage: ./verify.sh [resource-group-name]"
  exit 1
fi

echo "=== Exercise 13: CNI Deep Dive ==="
echo "  ℹ️  Control plane: $CP_IP (running checks via SSH)"
echo ""

# Helper: run a command on the control plane via SSH
ssh_cmd() {
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "azureuser@$CP_IP" "$@" 2>/dev/null
}

check() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  ✅ $desc"; ((PASS++))
  else
    echo "  ❌ $desc"; ((FAIL++))
  fi
}

bonus() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  🌟 (bonus) $desc"; ((BONUS_PASS++))
  else
    echo "  ⬜ (bonus) $desc — skipped or not yet done"; ((BONUS_FAIL++))
  fi
}

echo "— Challenge 1: kubeadm cluster initialized —"
check "kubectl is responsive on control plane" \
  "ssh_cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes'"

echo ""
echo "— Challenge 2: Worker nodes joined —"
NODE_COUNT=$(ssh_cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes --no-headers 2>/dev/null | wc -l')
check "Cluster has 3 nodes (1 CP + 2 workers)" \
  "[[ '$NODE_COUNT' -ge 3 ]]"

echo ""
echo "— Challenge 3: CNI installed (nodes are Ready) —"
READY_COUNT=$(ssh_cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes --no-headers 2>/dev/null | grep -c " Ready "')
check "All nodes are in Ready state" \
  "[[ '$READY_COUNT' -ge 3 ]]"

echo ""
echo "— Challenge 4: CNI config files present —"
check "CNI config exists in /etc/cni/net.d/" \
  "ssh_cmd 'ls /etc/cni/net.d/*.conflist 2>/dev/null || ls /etc/cni/net.d/*.conf 2>/dev/null'"

echo ""
echo "— Challenge 5: CNI network interfaces created —"
check "CNI-related interfaces exist (cali*, tunl0, flannel*, or vxlan*)" \
  "ssh_cmd 'ip link show 2>/dev/null | grep -qE \"cali|tunl0|flannel|vxlan|cni\"'"

echo ""
echo "— Challenge 6: Pods running across nodes —"
POD_STATUS=$(ssh_cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A --no-headers 2>/dev/null | grep -v Completed | grep -c Running')
check "System pods are Running" \
  "[[ '$POD_STATUS' -ge 4 ]]"

echo ""
echo "— Challenge 7: Cross-node pod connectivity —"
# Check if user test pods exist and are running
TEST_PODS=$(ssh_cmd 'sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pods --no-headers 2>/dev/null | grep -c Running' || echo "0")
check "User pods deployed for connectivity testing" \
  "[[ '$TEST_PODS' -ge 1 ]]"

echo ""
echo "— Bonus: Flannel comparison —"
bonus "Flannel was tested (flannel interface exists or flannel config present)" \
  "ssh_cmd 'ip link show flannel.1 2>/dev/null || ls /etc/cni/net.d/*flannel* 2>/dev/null'"

echo ""
echo "========================================"
echo "Core:  $PASS passed, $FAIL failed"
echo "Bonus: $BONUS_PASS passed, $BONUS_FAIL skipped"
echo "========================================"
