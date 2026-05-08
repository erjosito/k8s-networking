#!/bin/bash
# ============================================================================
# Tear down the CKNE lab environment
# ============================================================================
# Usage:
#   chmod +x cleanup.sh
#   ./cleanup.sh [resource-group-name]
# ============================================================================

set -euo pipefail

RG="${1:-ckne-lab}"

echo "==> Deleting resource group: $RG (this may take several minutes)"
az group delete --name "$RG" --yes --no-wait

echo "✅ Resource group deletion initiated. It will complete in the background."
