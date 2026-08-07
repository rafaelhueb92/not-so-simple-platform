# GitOps Platform Demo 🚀

[![GitHub Workflow](https://img.shields.io/github/actions/workflow/status/rafaelhueb92/not-so-simple-platform/.github/workflows/app-ci.yml?branch=master&label=CI)](https://github.com/rafaelhueb92/not-so-simple-platform/actions)
[![License](https://img.shields.io/github/license/rafaelhueb92/not-so-simple-platform)](LICENSE)

Minimal infrastructure demo showing:

- Containerized FastAPI app with Prometheus metrics
- Kubernetes manifests + GitOps via ArgoCD
- Local dev with Kind + local image load
- Terraform-driven AWS EKS infrastructure
- CI with GitHub Actions + OIDC-based AWS auth
- Security scanning, ECR publishing, destroy flows

## 🚀 Quickstart

These steps get a local Kind cluster running and deploy the app.

```bash
./scripts/kind-create.sh
./scripts/load-image.sh
./scripts/kind-label-taint.sh
./scripts/deploy-local.sh
```

Optional monitoring stack:

```bash
./scripts/deploy-monitoring-local.sh
```

See `docs/walkthrough.md` for a guided tour.

## 🔧 Local development notes

- `app/Dockerfile` expects the build context to be `app`
- the app source lives in `app/src`
- local Kind image loading uses `not-so-simple-platform-cluster-dev-py:v1.0`

If `dev/init.sh` is used, it builds from `app/Dockerfile` with context `app`, then loads the image into Kind.

## 💾 Terraform state bucket bootstrap

The repo includes `config/` for bootstrapping the Terraform S3 state bucket.

This is a manual step and should not run in CI:

```bash
cd config
terraform init
terraform apply -var="bucket_name=my-tf-state-bucket"
```

Once created, set the bucket name in GitHub variables/secrets and in your Terraform backend config.

## 🧠 GitHub Actions + OIDC role

This repo uses GitHub Actions and AWS OIDC to avoid long-lived AWS keys.

### Required GitHub repo secrets / variables

Set one of these name pairs in GitHub repo settings:

- `ECR_REGISTRY` = `<AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com`
- `ECR_REPOSITORY` = `<your-ecr-repo-name>`
- `AWS_REGION` = `us-east-1`
- `AWS_ROLE_TO_ASSUME` = the IAM role ARN for GitHub Actions

The workflow also accepts the alternate names:

- `AWS_ECR_REGISTRY`
- `AWS_ECR_REPOSITORY`

### OIDC role generation

Use [`oidc-github-actions-role-aws`](https://github.com/rafaelhueb92/oidc-github-actions-role-aws) to generate the IAM role and trust policy for GitHub Actions.

That project helps create a role that:

- trusts GitHub Actions via OIDC
- allows ECR image push/pull
- allows Terraform operations against AWS
- avoids embedding AWS credentials in workflows

## 🗂️ Repository layout

- `app/` — application packaging and Kubernetes deployment
  - `app/Dockerfile` — multi-stage Python image build
  - `app/src/` — FastAPI app code, metrics, and dependencies
  - `app/manifest/` — ArgoCD-aware Kubernetes YAML manifests

- `config/` — Terraform bootstrap for the remote state bucket
  - `config/main.tf` and `config/variables.tf`
  - `config/README.md` explains how to create the S3 state bucket

- `dev/` — local Kind / ArgoCD / monitoring helpers
  - `dev/init.sh` — bootstrap local Kind cluster, ArgoCD, and Prometheus stack
  - `dev/kind-config.yaml` — Kind cluster config with taints/labels
  - `dev/prometheus-values.yaml` — local monitoring Helm values
  - `dev/argocd-application.yaml` — ArgoCD application manifest

- `infra/` — AWS infrastructure Terraform for EKS and supporting resources
  - `infra/main.tf`, `backend.tf`, and `variables.tf`
  - `infra/terraform.tfstate` and `.terraform/`

- `.github/workflows/` — GitHub Actions CI/CD definitions
  - `.github/workflows/app-ci.yml` — app build/test/security/docker pipeline

- `scripts/` — convenience scripts for local setup and deployment
  - `scripts/kind-create.sh`
  - `scripts/load-image.sh`
  - `scripts/kind-label-taint.sh`
  - `scripts/deploy-local.sh`
  - `scripts/deploy-monitoring-local.sh`

- `permission-policy.example.json` — example IAM policy for Terraform and ECR access

## 📌 What this repo includes

- `app/Dockerfile` — multi-stage Python build for the FastAPI service
- `app/src/` — application source and requirements
- `app/manifest/` — Kubernetes manifests for ArgoCD deployment
- `.github/workflows/app-ci.yml` — CI/CD pipeline
- `dev/init.sh` — Kind cluster + ArgoCD + monitoring bootstrap
- `infra/` — Terraform and AWS infra configuration

## 📈 Monitoring

The cluster installs the `kube-prometheus-stack` chart with Prometheus, Grafana, Alertmanager, node-exporter, and kube-state-metrics.

### Dedicated monitoring node

The monitoring stack is pinned to a node with:

- `dedicated=monitoring:NoSchedule`
- a matching `nodeSelector` and `tolerations`
- `dev/kind-config.yaml` for Kind, and `infra/eks/monitoring-nodegroup.yaml` for EKS

### Access Grafana

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-grafana 3000:80
```

Open `http://localhost:3000` and use the password in `secret-grafana.txt`.

### Access Prometheus

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-kube-prome-prometheus 9090
```

Then visit:

- `http://localhost:9090/targets`
- `http://localhost:9090/graph`

### Metrics scraping

1. App exposes `/metrics` with `hello_requests_total`
2. `app/manifest/servicemonitor.yaml` selects service label `app: hello`
3. Prometheus uses the ServiceMonitor and Helm values for discovery

## 🔗 Helpful links

- [`docs/walkthrough.md`](docs/walkthrough.md) — guided tour of repo flow
- [`dev/init.sh`](dev/init.sh) — local Kind + ArgoCD bootstrap script
- [`app/Dockerfile`](app/Dockerfile) — local and CI build definition
- [`app/manifest/`](app/manifest/) — Kubernetes manifests for ArgoCD
- [`infra/`](infra/) — Terraform infra configuration
- [`oidc-github-actions-role-aws`](https://github.com/rafaelhueb92/oidc-github-actions-role-aws) — OIDC role generator for GitHub Actions
- [`kubernetes-sigs/cloud-provider-kind`](https://github.com/kubernetes-sigs/cloud-provider-kind) — Kind load balancer support
- [`prometheus-community/kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) — monitoring Helm chart
