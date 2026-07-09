#!/usr/bin/env bash
set -euo pipefail

kubectl -n wiz-lab get pods -o wide
kubectl -n wiz-lab get deploy,svc,ingress
kubectl -n wiz-lab exec deploy/wiz-todo -- cat /app/wizexercise.txt
kubectl -n wiz-lab auth can-i '*' '*' --as=system:serviceaccount:wiz-lab:wiz-todo-sa
