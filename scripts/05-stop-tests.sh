#!/usr/bin/env bash
set -euo pipefail
kubectl delete pod load-generator availability-checker --ignore-not-found=true
echo "Testes interrompidos. Observe a redução com: kubectl get hpa,pods,nodes --watch"
