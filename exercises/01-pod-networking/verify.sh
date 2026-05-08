#!/bin/bash
# ============================================================================
# Exercise 01 — Pod-to-Pod Networking: Verification Script
# ============================================================================
set -uo pipefail

PASS=0; FAIL=0; BONUS_PASS=0; BONUS_FAIL=0

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

echo "=== Exercise 01: Pod-to-Pod Networking ==="
echo ""

echo "— Challenge 1: Deploy frontend and backend pods on different nodes —"
check "Pod 'frontend' exists and is Running" \
  "kubectl get pod frontend -o jsonpath='{.status.phase}' | grep -q Running"
check "Pod 'backend' exists and is Running" \
  "kubectl get pod backend -o jsonpath='{.status.phase}' | grep -q Running"
FRONTEND_NODE=$(kubectl get pod frontend -o jsonpath='{.spec.nodeName}' 2>/dev/null)
BACKEND_NODE=$(kubectl get pod backend -o jsonpath='{.spec.nodeName}' 2>/dev/null)
if [[ -n "$FRONTEND_NODE" && -n "$BACKEND_NODE" && "$FRONTEND_NODE" != "$BACKEND_NODE" ]]; then
  echo "  ✅ Pods are on different nodes ($FRONTEND_NODE vs $BACKEND_NODE)"; ((PASS++))
else
  echo "  ❌ Pods should be on different nodes (got: $FRONTEND_NODE, $BACKEND_NODE)"; ((FAIL++))
fi

echo ""
echo "— Challenge 2: Verify pod-to-pod connectivity —"
BACKEND_IP=$(kubectl get pod backend -o jsonpath='{.status.podIP}' 2>/dev/null)
if [[ -n "$BACKEND_IP" ]]; then
  check "frontend can reach backend at $BACKEND_IP" \
    "kubectl exec frontend -- wget -qO- --timeout=5 http://$BACKEND_IP"
else
  echo "  ❌ Cannot determine backend pod IP"; ((FAIL++))
fi
FRONTEND_IP=$(kubectl get pod frontend -o jsonpath='{.status.podIP}' 2>/dev/null)
if [[ -n "$FRONTEND_IP" ]]; then
  check "backend can reach frontend at $FRONTEND_IP" \
    "kubectl exec backend -- wget -qO- --timeout=5 http://$FRONTEND_IP"
else
  echo "  ❌ Cannot determine frontend pod IP"; ((FAIL++))
fi

echo ""
echo "— Challenge 3: Multi-container (sidecar) pod —"
check "Pod 'frontend-debug' exists and is Running" \
  "kubectl get pod frontend-debug -o jsonpath='{.status.phase}' | grep -q Running"
CONTAINER_COUNT=$(kubectl get pod frontend-debug -o jsonpath='{.spec.containers[*].name}' 2>/dev/null | wc -w)
check "Pod 'frontend-debug' has at least 2 containers" \
  "[[ $CONTAINER_COUNT -ge 2 ]]"

echo ""
echo "— Bonus: hostNetwork pod —"
bonus "A pod with hostNetwork: true exists" \
  "kubectl get pods -o jsonpath='{range .items[?(@.spec.hostNetwork==true)]}{.metadata.name}{end}' | grep -q ."

echo ""
echo "========================================"
echo "Core:  $PASS passed, $FAIL failed"
echo "Bonus: $BONUS_PASS passed, $BONUS_FAIL skipped"
echo "========================================"
