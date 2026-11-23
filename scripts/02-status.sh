#!/usr/bin/env bash
set -euo pipefail
kubectl get hpa php-apache
kubectl get deployment,service php-apache
kubectl get pods -l app=php-apache -o wide
kubectl get nodes -o wide
kubectl top pods -l app=php-apache || true
