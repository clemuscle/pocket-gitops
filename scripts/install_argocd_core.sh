#!/usr/bin/env bash
set -euo pipefail
ARGOCD_VERSION=${ARGOCD_VERSION:-v2.11.5}

# namespace + manifest Core
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl -n argocd apply -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/core-install.yaml

# resources limits (idempotent patch)
for d in argocd-server argocd-repo-server argocd-application-controller argocd-redis; do
  kubectl -n argocd set resources deployment/$d \
    --limits=memory=120Mi --requests=memory=60Mi || true
done

# port-forward UI (bg)
kubectl -n argocd port-forward svc/argocd-server 8080:80 >/dev/null 2>&1 &
echo "Argo CD UI ➜ http://localhost:8080 (admin / $( \
  kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d))"
