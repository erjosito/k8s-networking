#!/bin/bash
# ============================================================================
# Exercise 10 — Service Debugging: Verification Script
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

echo "=== Exercise 10: Service Debugging ==="
echo ""

echo "— Challenge 1: staging namespace exists —"
check "Namespace 'staging' exists" \
  "kubectl get namespace staging"

echo ""
echo "— Bug Fix 1: Label mismatch —"
# The deployment should have label app=frontend (not front-end)
DEPLOY_LABEL=$(kubectl get deployment frontend -n staging -o jsonpath='{.spec.template.metadata.labels.app}' 2>/dev/null)
SVC_SELECTOR=$(kubectl get svc frontend-svc -n staging -o jsonpath='{.spec.selector.app}' 2>/dev/null)
check "Deployment label matches service selector (app=$SVC_SELECTOR)" \
  "[[ '$DEPLOY_LABEL' == '$SVC_SELECTOR' ]]"

echo ""
echo "— Bug Fix 2: Correct targetPort —"
TARGET_PORT=$(kubectl get svc frontend-svc -n staging -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
check "frontend-svc targetPort is 80 (not 8080)" \
  "[[ '$TARGET_PORT' == '80' ]]"

echo ""
echo "— Bug Fix 3: NetworkPolicy allows traffic —"
# Check that there's an allow policy for frontend ingress
check "NetworkPolicy 'allow-frontend-ingress' exists in staging" \
  "kubectl get networkpolicy allow-frontend-ingress -n staging"

echo ""
echo "— Overall: Service works end-to-end —"
SVC_IP=$(kubectl get svc frontend-svc -n staging -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [[ -n "$SVC_IP" ]]; then
  check "frontend-svc in staging is reachable" \
    "kubectl run verify-staging --rm -i --restart=Never -n staging --image=busybox -- wget -qO- --timeout=5 http://$SVC_IP 2>/dev/null"
fi

echo ""
echo "— Endpoints populated —"
EP_COUNT=$(kubectl get endpoints frontend-svc -n staging -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | grep -c 'ip')
check "frontend-svc has at least 1 endpoint" \
  "[[ $EP_COUNT -ge 1 ]]"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
