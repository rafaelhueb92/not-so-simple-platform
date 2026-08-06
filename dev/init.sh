#! /bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

echo ""
echo "======================================"
echo "Creating Kind Cluster..."
echo "======================================"

kind create cluster --name not-so-simple-platform-cluster-dev --config "${REPO_ROOT}/dev/kind-config.yaml"

echo ""
echo "======================================"
echo "Removing node.kubernetes.io/exclude-from-external-load-balancers label from the control-plane node..."
echo "======================================"

kubectl label node not-so-simple-platform-cluster-dev-control-plane node.kubernetes.io/exclude-from-external-load-balancers-

echo ""
echo "======================================"
echo "Adding Helm repositories..."
echo "======================================"

helm repo add argocd https://argoproj.github.io/argo-helm

echo ""
echo "======================================"
echo "Installing ArgoCD..."
echo "======================================"
helm upgrade --install argocd argocd/argo-cd \
  --namespace argocd \
  -f "${REPO_ROOT}/dev/argocd-values.yaml" \
  --create-namespace \
  --wait

echo "Creating file secret-argo.txt with ArgoCD initial admin password..."
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d > secret-argo.txt

echo ""
echo "======================================"
echo "Installing Prometheus Comunity..."
echo "======================================"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus prometheus-community/kube-prometheus-stack

echo ""
echo "======================================"
echo "Building Docker images..."
echo "======================================"

docker build -t not-so-simple-platform-cluster-dev-py:v1.0 -f "${REPO_ROOT}/app/Dockerfile" "${REPO_ROOT}/app/src"

echo ""
echo "======================================"
echo "Adding Image into the Kind repositories..."
echo "======================================"

kind load -n not-so-simple-platform-cluster-dev docker-image not-so-simple-platform-cluster-dev-py:v1.0

echo ""
echo "======================================"
echo "Adding Argo App..."
echo "======================================"

kubectl apply -f "${REPO_ROOT}/app/manifest/argocd-application.yaml"