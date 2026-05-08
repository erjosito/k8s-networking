#!/bin/bash
# ============================================================================
# Exercise 06 — Network Policy (Ingress Rules): Verification Script
# ============================================================================
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if eval "$@" &>/dev/null; then
    echo "  ✅ $desc"; ((PASS++))
  else
    echo "  ❌ $desc"; ((FAIL++))
  fi
}

echo "=== Exercise 06: Network Policy — Ingress Rules ==="
echo ""

echo "— Challenge 1: Default-deny ingress policy —"
check "NetworkPolicy 'default-deny-ingress' exists" \
  "kubectl get networkpolicy default-deny-ingress"
POD_SEL=$(kubectl get networkpolicy default-deny-ingress -o jsonpath='{.spec.podSelector}' 2>/dev/null)
check "default-deny-ingress targets all pods (empty podSelector)" \
  "[[ '$POD_SEL' == '{}' || '$POD_SEL' == '' ]]"

echo ""
echo "— Challenge 2: Allow frontend -> backend —"
check "NetworkPolicy 'allow-frontend-to-backend' exists" \
  "kubectl get networkpolicy allow-frontend-to-backend"

echo ""
echo "— Challenge 3: Allow backend -> database —"
check "NetworkPolicy 'allow-backend-to-database' exists" \
  "kubectl get networkpolicy allow-backend-to-database"

echo ""
echo "— Challenge 4: Verify enforcement —"
BACKEND_IP=$(kubectl get svc backend-svc -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [[ -n "$BACKEND_IP" ]]; then
  check "frontend -> backend is ALLOWED" \
    "kubectl exec deploy/frontend -- wget -qO- --timeout=5 http://$BACKEND_IP 2>/dev/null"
  echo "  ℹ️  Testing that unauthorized pods are blocked (may timeout — that's expected)..."
  if kubectl run verify-outsider --rm -i --restart=Never --image=busybox --timeout=10s -- wget -qO- --timeout=3 "http://$BACKEND_IP" &>/dev/null; then
    echo "  ❌ Outsider pod can still reach backend (policy not enforced)"; ((FAIL++))
  else
    echo "  ✅ Outsider pod is blocked from backend"; ((PASS++))
  fi
fi

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
