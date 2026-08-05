#!/bin/bash
set -euo pipefail
NODE=$(kubectl get nodes -o name | grep worker | tail -n1 | sed 's|node/||')
kubectl label node "$NODE" nodepool=argocd --overwrite
kubectl taint nodes "$NODE" dedicated=argocd:NoSchedule --overwrite
