#! /bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ensure_hosts_entry() {
  local host_entry='127.0.0.1 hello.local'

  if grep -qE '^127\.0\.0\.1[[:space:]]+hello\.local$' /etc/hosts; then
    echo "hello.local already present in /etc/hosts"
    return 0
  fi

  if [ "$(id -u)" -eq 0 ]; then
    printf '\n%s\n' "$host_entry" >> /etc/hosts
  elif command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "$host_entry" | sudo tee -a /etc/hosts >/dev/null
  else
    echo "Unable to update /etc/hosts automatically; please add '$host_entry' manually" >&2
  fi
}

echo ""
echo "======================================"
echo "Creating Kind Cluster..."
echo "======================================"

kind create cluster --name not-so-simple-platform-cluster-dev --config "${REPO_ROOT}/dev/kind-config.yaml"

echo ""
echo "======================================"
echo "Installing Gateway API CRDs..."
echo "======================================"

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl wait --for=condition=Established crd/gatewayclasses.gateway.networking.k8s.io --timeout=180s
kubectl wait --for=condition=Established crd/gateways.gateway.networking.k8s.io --timeout=180s
kubectl wait --for=condition=Established crd/httproutes.gateway.networking.k8s.io --timeout=180s

echo ""
echo "======================================"
echo "Configuring host entry for Ingress . . ."
echo "======================================"

ensure_hosts_entry

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
echo "Building Docker images..."
echo "======================================"

docker build -t not-so-simple-platform-cluster-dev-py:v1.0 "${REPO_ROOT}/app"


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