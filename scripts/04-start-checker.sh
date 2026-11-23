#!/usr/bin/env bash
set -euo pipefail
kubectl delete pod availability-checker --ignore-not-found=true
kubectl run availability-checker --image=busybox:1.36 --restart=Never --command -- /bin/sh -c 'while true; do date -u; if wget -T 2 -q -O- http://php-apache.default.svc.cluster.local >/dev/null; then echo OK; else echo FALHA; fi; sleep 1; done'
echo "Verificador iniciado. Logs: kubectl logs -f availability-checker"
