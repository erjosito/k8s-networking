#!/bin/bash
# ============================================================================
# Exercise 08 — Ingress Controllers: Verification Script
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

echo "=== Exercise 08: Ingress Controllers & Ingress Resources ==="
echo ""

echo "— Challenge 1: NGINX Ingress Controller —"
check "Namespace 'ingress-nginx' exists" \
  "kubectl get namespace ingress-nginx"
check "Ingress controller pods are Running" \
  "kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -q Running"

INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [[ -n "$INGRESS_IP" ]]; then
  echo "  ℹ️  Ingress controller external IP: $INGRESS_IP"
else
  echo "  ⚠️  No external IP found on ingress controller service"
fi

echo ""
echo "— Challenge 2: Path-based Ingress —"
check "Ingress 'bookstore-paths' exists" \
  "kubectl get ingress bookstore-paths"

echo ""
echo "— Challenge 3: Host-based Ingress —"
check "Ingress 'bookstore-hosts' exists" \
  "kubectl get ingress bookstore-hosts"

if [[ -n "$INGRESS_IP" ]]; then
  check "Host-based routing works for bookstore.example.com" \
    "curl -s --max-time 5 -H 'Host: bookstore.example.com' http://$INGRESS_IP | grep -qi 'html\|nginx\|welcome'"
fi

echo ""
echo "— Challenge 4: TLS termination —"
check "Ingress 'bookstore-tls' exists" \
  "kubectl get ingress bookstore-tls"
check "TLS secret 'bookstore-tls' exists" \
  "kubectl get secret bookstore-tls"

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"
