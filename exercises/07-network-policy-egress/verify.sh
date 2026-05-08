#!/bin/bash
# ============================================================================
# Exercise 07 — Network Policy (Egress Rules): Verification Script
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

echo "=== Exercise 07: Network Policy — Egress Rules ==="
echo ""

echo "— Challenge 1: Default-deny egress policy —"
check "NetworkPolicy 'default-deny-egress' exists" \
  "kubectl get networkpolicy default-deny-egress"

echo ""
echo "— Challenge 2: Allow DNS egress —"
check "NetworkPolicy 'allow-dns' exists" \
  "kubectl get networkpolicy allow-dns"

echo ""
echo "— Challenge 3: Allow backend external access —"
check "NetworkPolicy 'allow-backend-external' exists" \
  "kubectl get networkpolicy allow-backend-external"

echo ""
echo "— Challenge 4: Verify enforcement —"
check "backend can resolve DNS (via labeled pod)" \
  "kubectl run verify-dns-be --rm -i --restart=Never --overrides='{\"metadata\":{\"labels\":{\"app\":\"backend\"}}}' --image=busybox -- nslookup httpbin.org 2>/dev/null"

echo "  ℹ️  Testing backend -> httpbin.org (may take a few seconds)..."
if kubectl run verify-egress-be --rm -i --restart=Never --overrides='{"metadata":{"labels":{"app":"backend"}}}' --image=busybox -- wget -qO- --timeout=10 http://httpbin.org/get &>/dev/null; then
  echo "  ✅ backend -> httpbin.org is ALLOWED"; ((PASS++))
else
  echo "  ❌ backend -> httpbin.org is BLOCKED (should be allowed)"; ((FAIL++))
fi

echo "  ℹ️  Testing frontend -> httpbin.org (should timeout — that's expected)..."
if kubectl run verify-egress-fe --rm -i --restart=Never --overrides='{"metadata":{"labels":{"app":"frontend"}}}' --image=busybox -- wget -qO- --timeout=5 http://httpbin.org/get &>/dev/null; then
  echo "  ❌ frontend -> httpbin.org is ALLOWED (should be blocked)"; ((FAIL++))
else
  echo "  ✅ frontend -> httpbin.org is BLOCKED"; ((PASS++))
fi

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
