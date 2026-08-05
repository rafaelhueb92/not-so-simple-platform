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
