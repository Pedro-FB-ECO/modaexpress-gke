#!/usr/bin/env bash
set -euo pipefail
kubectl delete pod load-generator --ignore-not-found=true
kubectl run load-generator --image=busybox:1.36 --restart=Never --command -- /bin/sh -c 'while true; do wget -q -O- http://php-apache.default.svc.cluster.local >/dev/null; sleep 0.01; done'
echo "Carga iniciada. Logs: kubectl logs -f load-generator"
