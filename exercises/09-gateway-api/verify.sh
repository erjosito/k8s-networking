#!/bin/bash
# ============================================================================
# Exercise 09 — Gateway API: Verification Script
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

echo "=== Exercise 09: Gateway API ==="
echo ""

echo "— Challenge 1: Gateway API CRDs —"
check "GatewayClass CRD is installed" \
  "kubectl get crd gatewayclasses.gateway.networking.k8s.io"
check "HTTPRoute CRD is installed" \
  "kubectl get crd httproutes.gateway.networking.k8s.io"

echo ""
echo "— Challenge 2: GatewayClass and Gateway —"
check "A GatewayClass exists" \
  "kubectl get gatewayclass --no-headers 2>/dev/null | grep -q ."
check "Gateway 'bookstore-gateway' exists" \
  "kubectl get gateway bookstore-gateway"

echo ""
echo "— Challenge 3: backend-v2 deployment —"
check "Deployment 'backend-v2' exists" \
  "kubectl get deployment backend-v2"
check "Service 'backend-v2-svc' exists" \
  "kubectl get svc backend-v2-svc"

echo ""
echo "— Challenge 4: HTTPRoutes —"
HTTPROUTE_COUNT=$(kubectl get httproute --no-headers 2>/dev/null | wc -l)
check "At least one HTTPRoute exists" \
  "[[ $HTTPROUTE_COUNT -ge 1 ]]"

echo ""
echo "— Challenge 5: Weighted canary routing —"
# Check if any HTTPRoute has backendRefs with weights
check "A canary/weighted HTTPRoute exists" \
  "kubectl get httproute -o json 2>/dev/null | grep -q weight"

echo ""
echo "— Bonus: GRPCRoute —"
bonus "GRPCRoute CRD is installed" \
  "kubectl get crd grpcroutes.gateway.networking.k8s.io"
bonus "A GRPCRoute resource exists" \
  "kubectl get grpcroute --no-headers 2>/dev/null | grep -q ."

echo ""
echo "========================================"
echo "Core:  $PASS passed, $FAIL failed"
echo "Bonus: $BONUS_PASS passed, $BONUS_FAIL skipped"
echo "========================================"
