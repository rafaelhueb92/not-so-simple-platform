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

echo "Creating 'monitoring' namespace and Grafana admin secret..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

GRAFANA_PASSWORD="$(openssl rand -base64 18)"
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="${GRAFANA_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "${GRAFANA_PASSWORD}" > secret-grafana.txt
echo "Grafana admin password written to secret-grafana.txt"

helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f "${REPO_ROOT}/dev/prometheus-values.yaml"

echo "Loading Grafana dashboard (hello-dashboard.json) via sidecar ConfigMap..."
kubectl -n monitoring create configmap hello-dashboard \
  --from-file=hello-dashboard.json="${REPO_ROOT}/dev/dashboards/hello-dashboard.json" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring label configmap hello-dashboard grafana_dashboard=1 --overwrite

echo ""
echo "======================================"
echo "Building Docker images..."
echo "======================================"

docker build -t not-so-simple-platform-cluster-dev-py:v1.0 -f "${REPO_ROOT}/app/Dockerfile" "${REPO_ROOT}/app"

echo ""
echo "======================================"
echo "Adding Image into the Kind repositories..."
echo "======================================"

kind load -n not-so-simple-platform-cluster-dev docker-image not-so-simple-platform-cluster-dev-py:v1.0

echo ""
echo "======================================"
echo "Adding Argo App..."
echo "======================================"

kubectl apply -f "${REPO_ROOT}/dev/argocd-application.yaml"

echo ""
echo "======================================"
echo "Run sudo cloud-provider-kind --enable-lb-port-mapping in a separate terminal to enable LoadBalancer support in Kind cluster."
echo "Access localhost:80"
echo "======================================"
echo "To Access the tools:"
echo ""
echo "Grafana: kubectl port-forward -n monitoring svc/prom-stack-grafana 3000:80"
echo "ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:80"
echo "======================================"