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
