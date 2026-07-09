#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${EKS_CLUSTER_NAME:?Set EKS_CLUSTER_NAME}"
: "${IMAGE_URI:?Set IMAGE_URI}"
: "${MONGO_URI_SSM_PARAMETER:?Set MONGO_URI_SSM_PARAMETER}"

if ! command -v envsubst >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y gettext-base
fi

aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

MONGO_URI=$(aws ssm get-parameter \
  --name "$MONGO_URI_SSM_PARAMETER" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query 'Parameter.Value' \
  --output text)

kubectl apply -f k8s/namespace.yaml
kubectl -n wiz-lab create secret generic mongo-uri \
  --from-literal=MONGO_URI="$MONGO_URI" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/rbac-cluster-admin.yaml

envsubst < k8s/deployment.yaml | kubectl apply -f -
kubectl -n wiz-lab rollout status deploy/wiz-todo --timeout=300s

kubectl -n ingress-nginx get svc ingress-nginx-controller
