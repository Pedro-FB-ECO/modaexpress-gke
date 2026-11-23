#!/usr/bin/env bash
set -euo pipefail
echo "== Confira o projeto e o contexto =="
gcloud config get-value project
kubectl config current-context
kubectl get nodes
echo "== Aplicando Deployment e Service =="
kubectl apply -f kubernetes/php-apache.yaml
kubectl rollout status deployment/php-apache --timeout=180s
echo "== Aplicando HPA 70% =="
kubectl apply -f kubernetes/hpa.yaml
kubectl get deployment,service,hpa,pods
