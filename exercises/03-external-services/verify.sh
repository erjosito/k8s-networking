#!/bin/bash
# ============================================================================
# Exercise 03 — External Services: Verification Script
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

echo "=== Exercise 03: External Services (NodePort, LoadBalancer, ExternalName) ==="
echo ""

echo "— Challenge 1: NodePort Service —"
check "Service 'frontend-nodeport' exists with type NodePort" \
  "kubectl get svc frontend-nodeport -o jsonpath='{.spec.type}' | grep -q NodePort"

echo ""
echo "— Challenge 2: LoadBalancer Service —"
check "Service 'frontend-lb' exists with type LoadBalancer" \
  "kubectl get svc frontend-lb -o jsonpath='{.spec.type}' | grep -q LoadBalancer"
LB_IP=$(kubectl get svc frontend-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [[ -n "$LB_IP" ]]; then
  check "LoadBalancer has an external IP assigned ($LB_IP)" "true"
else
  echo "  ❌ LoadBalancer has no external IP yet (may still be provisioning)"; ((FAIL++))
fi

echo ""
echo "— Challenge 3: externalTrafficPolicy: Local —"
ETP=$(kubectl get svc frontend-lb -o jsonpath='{.spec.externalTrafficPolicy}' 2>/dev/null)
check "frontend-lb has externalTrafficPolicy=Local" \
  "[[ '$ETP' == 'Local' ]]"

echo ""
echo "— Challenge 4: ExternalName Service —"
check "Service 'external-api' exists with type ExternalName" \
  "kubectl get svc external-api -o jsonpath='{.spec.type}' | grep -q ExternalName"
ENAME=$(kubectl get svc external-api -o jsonpath='{.spec.externalName}' 2>/dev/null)
check "external-api points to httpbin.org" \
  "[[ '$ENAME' == 'httpbin.org' ]]"

echo ""
echo "— Challenge 5: Service without selectors (legacy-db) —"
check "Service 'legacy-db' exists" \
  "kubectl get svc legacy-db"
SELECTOR=$(kubectl get svc legacy-db -o jsonpath='{.spec.selector}' 2>/dev/null)
check "legacy-db has no selector" \
  "[[ -z '$SELECTOR' || '$SELECTOR' == '{}' ]]"
check "EndpointSlice 'legacy-db-1' exists" \
  "kubectl get endpointslice legacy-db-1"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
