### 📘 Expanded Prompt for Claude: Full Repo Skeleton with Scalability Best Practices

> **Repo Name**: `not-so-simple-platform`
>
> **Objective**: Scaffold a complete, enterprise-ready GitOps platform demo focused on scalability, correctness, and clean patterns — suitable for a senior-level technical interview.
>
> **Key Requirements**
>
> - ✅ Fully local reproducible: no AWS apply, no cloud costs.
> - 🐳 Containerized app with multi-stage Dockerfile: best-practice layers, slim runtime, non-root user.
> - 🧪 Unit-tested app with coverage.
> - 📦 Kubernetes manifests: Helm or Kustomize preferred (use Kustomize unless Helm simplifies).
> - ⚙️ Terraform: modular, composable EKS caller using git module; plan-only mode by default.
> - 📊 Monitoring: Prometheus metrics, ServiceMonitor, local kube-prometheus-stack, AMP/AMG stubs.
> - 🔄 GitOps: ArgoCD Application manifest in `app/manifest/`.
> - 🛡️ IAM/Security: IRSA-ready roles, ECR read permissions, OIDC trust policies.
> - 📜 CI/CD: GitHub Actions with path filters, plan-only Terraform, no secrets stored.
> - 🧰 Scripts: Reproducible `kind` setup with registry, image loading, taint/label simulation.
> - 📄 Documentation: Concise README, 2–4 minute walkthrough script, architecture trade-offs.

---

### 🗂️ Complete File Specification

#### 📁 `app/`

##### `app/src/main.py`
```python
from fastapi import FastAPI
from starlette.responses import PlainTextResponse
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST, REGISTRY
import os

REQUEST_COUNT = Counter("hello_requests_total", "Total requests")

app = FastAPI()

@app.get("/", response_class=PlainTextResponse)
def read_root():
    REQUEST_COUNT.inc()
    return "Hello World"

@app.get("/health", response_class=PlainTextResponse)
def health_check():
    return "ok"

@app.get("/metrics")
def metrics():
    data = generate_latest(REGISTRY)
    return PlainTextResponse(content=data, media_type=CONTENT_TYPE_LATEST)
```

##### `app/src/metrics.py`
```python
from prometheus_client import Counter
REQUEST_COUNT = Counter("hello_requests_total", "Total requests")
```

##### `app/src/tests/test_main.py`
```python
from fastapi.testclient import TestClient
from ..main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.text == "Hello World"

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.text == "ok"

def test_metrics():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert b"hello_requests_total" in response.content
```

##### `app/src/requirements.txt`
```
fastapi==0.95.0
uvicorn[standard]==0.21.0
prometheus-client==0.16.0
```

##### `app/Dockerfile` (*Multi-stage, scalable*)
```dockerfile
# Stage 1: Builder
FROM python:3.11-slim as builder
WORKDIR /app
COPY app/src/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim
WORKDIR /app

# Copy deps from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# Copy app
COPY app/src .

# Non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

##### `app/manifest/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-app
  labels:
    app: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello
          image: localhost:5000/hello:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
            initialDelaySeconds: 2
            periodSeconds: 5
```

##### `app/manifest/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-service
  labels:
    app: hello
spec:
  selector:
    app: hello
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
```

##### `app/manifest/servicemonitor.yaml`
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: hello-servicemonitor
  labels:
    app: hello
spec:
  selector:
    matchLabels:
      app: hello
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

##### `app/manifest/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - servicemonitor.yaml
```

##### `app/dashboards/hello-dashboard.json`
```json
{
  "dashboard": {
    "title": "Hello App Metrics",
    "panels": [
      {
        "title": "Requests Total",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(hello_requests_total[5m])",
            "legendFormat": "requests/sec"
          }
        ]
      }
    ],
    "schemaVersion": 16,
    "version": 1
  }
}
```

##### `app/README.md`
```markdown
# App Development Guide

## Run Locally
```
cd app/src
pip install -r requirements.txt
uvicorn main:app --reload
```

Available endpoints:
- `/` → Hello World
- `/health` → Health check
- `/metrics` → Prometheus metrics
```

---

#### 📁 `infra/`

##### `infra/eks/main.tf`
```hcl
module "eks" {
  source = "git::https://github.com/rafaelhueb92/terraform-module-eks-poc.git//?ref=feat/taint-argocd"
  cluster_name = var.cluster_name
  region       = var.region
  install_argocd = var.install_argocd
}
```

##### `infra/eks/variables.tf`
```hcl
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "install_argocd" {
  description = "Install ArgoCD in cluster"
  type        = bool
  default     = false
}
```

##### `infra/eks/outputs.tf`
```hcl
output "cluster_name" {
  value = module.eks.cluster_name
}
```

##### `infra/eks/README.md`
```markdown
# EKS Infra Caller

Example caller for reusable EKS module.

## Usage

Run with:
```
terraform plan -var="install_argocd=false"
```

**DO NOT APPLY** — this is for review only.
```

##### `infra/amp/main.tf`
```hcl
resource "aws_prometheus_workspace" "this" {
  alias = "hello-prometheus"
}
```

##### `infra/amg/main.tf`
```hcl
resource "aws_grafana_workspace" "this" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  name                     = "hello-grafana"
}
```

##### `infra/amg/datasource.tf`
```hcl
resource "grafana_data_source" "amp" {
  type = "prometheus"
  name = "AMP"
  url  = aws_prometheus_workspace.this.prometheus_endpoint
}
```

##### `infra/ecr/main.tf`
```hcl
resource "aws_ecr_repository" "hello" {
  name = "hello-app"
}
```

##### `infra/README.md`
```markdown
# Infra Folder Overview

- `eks/` — EKS caller using reusable module
- `amp/` — Stub for AWS Managed Prometheus
- `amg/` — Stub for AWS Managed Grafana
- `ecr/` — Stub for ECR repo
```

---

#### 📁 `config/`

##### `config/bootstrap/main.tf`
```hcl
resource "aws_s3_bucket" "tf_state" {
  bucket = var.bucket_name
  acl    = "private"
  versioning { enabled = true }
}

resource "aws_dynamodb_table" "tf_locks" {
  name           = "${var.bucket_name}-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
```

##### `config/bootstrap/variables.tf`
```hcl
variable "bucket_name" {
  description = "Terraform state bucket name"
  type        = string
}
```

##### `config/bootstrap/README.md`
```markdown
# Bootstrap Config

Creates S3 + DynamoDB for Terraform state.

**Manual Step Only!**

```
terraform apply -var="bucket_name=my-tf-state-bucket"
```

Never run in CI.
```

##### `config/ci-roles/github-actions-oidc.tf`
```hcl
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:ORG/REPO:ref:refs/heads/*"]
    }
  }
}
```

##### `config/ci-roles/assume-role-setup.md`
```markdown
Configure GitHub OIDC to assume an IAM role for Terraform.

Set up in AWS IAM console:
- Create an OIDC provider using GitHub Actions audience
- Create IAM role with trust policy allowing repo access
- Attach minimal Terraform policies (plan-only)
```

---

#### 📁 `scripts/`

All scripts should be executable (`chmod +x`) and compatible with macOS/Linux.

##### `scripts/kind-create.sh`
```bash
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
```

##### `scripts/kind-label-taint.sh`
```bash
#!/bin/bash
set -euo pipefail
NODE=$(kubectl get nodes -o name | grep worker | tail -n1 | sed 's|node/||')
kubectl label node "$NODE" nodepool=argocd --overwrite
kubectl taint nodes "$NODE" dedicated=argocd:NoSchedule --overwrite
```

##### `scripts/load-image.sh`
```bash
#!/bin/bash
set -euo pipefail
docker build -t hello:local -f app/Dockerfile .
docker tag hello:local localhost:5000/hello:latest
docker push localhost:5000/hello:latest
kind load docker-image localhost:5000/hello:latest
```

##### `scripts/deploy-local.sh`
```bash
#!/bin/bash
set -euo pipefail
kubectl apply -k app/manifest
kubectl wait --for=condition=Ready pods -l app=hello --timeout=120s
kubectl get pods -o wide
```

##### `scripts/deploy-monitoring-local.sh`
```bash
#!/bin/bash
set -euo pipefail
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring 2>/dev/null || true
helm install prom-stack prometheus-community/kube-prometheus-stack --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

---

#### 📁 `.github/workflows/`

##### `app-ci.yml`
```yaml
name: App CI
on:
  push:
    paths:
      - 'app/**'
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: pip install -r app/src/requirements.txt
      - run: pytest app/src/tests
```

##### `infra-ci.yml`
```yaml
name: Infra CI
on:
  push:
    paths:
      - 'infra/**'
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform plan -var="install_argocd=false"
```

##### `manifests-ci.yml`
```yaml
name: Manifests CI
on:
  push:
    paths:
      - 'app/manifest/**'
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -sSL -o kubeval https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64
          chmod +x kubeval
          find app/manifest -name "*.yaml" -exec ./kubeval {} \;
```

---

#### 📁 `docs/`

##### `walkthrough.md`
```markdown
# Interview Walkthrough Script (2–4 mins)

**Goal**: Demonstrate core DevOps infrastructure patterns (GitOps, containerization, Kubernetes, IaC, local dev) without cloud costs.

## Steps

1. `./scripts/kind-create.sh` — Start local cluster with registry.
2. `./scripts/load-image.sh` — Build and push image to local registry.
3. `./scripts/kind-label-taint.sh` — Simulate dedicated nodepool.
4. `./scripts/deploy-local.sh` — Deploy app and validate pod placement.
5. Show `/metrics` and Grafana dashboard (`./scripts/deploy-monitoring-local.sh`).
6. Open `infra/` — show EKS caller and AMP/AMG stubs.
7. Open `.github/workflows/` — explain path filtering and plan-only Terraform.
```

##### `architecture.md`
```markdown
# Architecture Decisions

- **App**: FastAPI, multi-stage Docker, unit tests, metrics endpoint.
- **Kubernetes**: Kustomize, ServiceMonitor, ArgoCD Application manifest.
- **Local Dev**: `kind` with local registry to mimic cloud behavior.
- **Infra**: Modular Terraform with git module; plan-only by default.
- **Monitoring**: Prometheus locally, AWS Managed for production.
- **CI**: GitHub Actions with path filters and OIDC trust.
```

##### `monitoring-local.md`
```markdown
# Local Monitoring

See `scripts/deploy-monitoring-local.sh`.

Installs Prometheus + Grafana with auto-discovery of ServiceMonitors.

Use port-forward:
```
kubectl port-forward -n monitoring svc/prom-stack-grafana 3000:80
```
Login: `admin` / `prom-operator`
```

---

#### 📁 Root-level Files

##### `README.md`
```markdown
# GitOps Platform Demo

Minimal infrastructure demo showing:

- Containerized FastAPI app with metrics
- Kubernetes manifests + GitOps (ArgoCD Application)
- Local dev with kind
- Terraform EKS module caller
- Monitoring: local Prometheus + AWS Managed stubs
- CI with GitHub Actions (plan-only)
- IAM/Security: OIDC, ECR read, IRSA-ready

## Quickstart

1. Run `./scripts/kind-create.sh`
2. Run `./scripts/load-image.sh`
3. Run `./scripts/kind-label-taint.sh`
4. Run `./scripts/deploy-local.sh`
5. Optional: `./scripts/deploy-monitoring-local.sh`

See `docs/walkthrough.md` for a guided tour.
```

##### `.gitignore`
```gitignore
__pycache__
*.pyc
.DS_Store
.terraform/
*.tfstate
*.tfstate.backup
.env
venv/
.coverage
```

---

