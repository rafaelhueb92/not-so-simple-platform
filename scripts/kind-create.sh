#!/bin/bash
set -euo pipefail
docker run -d --name kind-registry -p 5000:5000 registry:2
kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
containerdConfigPatches:
- |
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://host.docker.internal:5000"]
EOF
