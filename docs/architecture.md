# Architecture Decisions

- **App**: FastAPI, multi-stage Docker, unit tests, metrics endpoint.
- **Kubernetes**: Kustomize, ServiceMonitor, ArgoCD Application manifest.
- **Local Dev**: `kind` with local registry to mimic cloud behavior.
- **Infra**: Modular Terraform with git module; plan-only by default.
- **Monitoring**: Prometheus locally, AWS Managed for production.
- **CI**: GitHub Actions with path filters and OIDC trust.
