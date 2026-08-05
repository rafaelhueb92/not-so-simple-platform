#!/bin/bash
set -euo pipefail
kubectl apply -k app/manifest
kubectl wait --for=condition=Ready pods -l app=hello --timeout=120s
kubectl get pods -o wide
