# Runbook / Post-mortem: pin ArgoCD to run exclusively on worker3

- **Date:** 2026-08-06
- **Environment:** local dev — KIND cluster (`not-so-simple-platform-cluster-dev`)
- **Component:** ArgoCD (argo-cd Helm chart) + KIND node config
- **Goal:** dedicate worker3 to ArgoCD — ArgoCD runs there and nowhere else, and
  nothing else runs on worker3.
- **Status:** configured (applies on next `dev/init.sh`)

## Summary

The initial config only tainted worker3 and gave ArgoCD a matching toleration.
That is **incomplete**: a taint + toleration lets ArgoCD run on worker3 but does
not force it there — ArgoCD pods could still schedule on worker1/worker2. To
make worker3 exclusive to ArgoCD, three pieces are required together.

## The three-part mechanism

| Piece | Where | Effect |
|---|---|---|
| **Taint** `dedicated=argocd:NoSchedule` | worker3 (`kind-config.yaml`) | Repels *all other* pods from worker3 |
| **Toleration** `dedicated=argocd` | ArgoCD (`argocd-values.yaml`) | Lets ArgoCD *tolerate* the taint (may run there) |
| **NodeAffinity** `dedicated In [argocd]` | ArgoCD (`argocd-values.yaml`) | *Forces* ArgoCD onto worker3 (cannot run elsewhere) |

- Taint + toleration alone → "ArgoCD *may* run on worker3; nothing else can."
- Add hard nodeAffinity → "ArgoCD runs on worker3 **and nowhere else**."

Exclusive in both directions:
- **Nothing else on worker3:** the `NoSchedule` taint repels every pod without
  the toleration.
- **ArgoCD nowhere else:** the required (`hard`) nodeAffinity restricts ArgoCD to
  nodes labelled `dedicated=argocd` (only worker3).

## Configuration

### 1. worker3 — taint + label (`dev/kind-config.yaml`)

The label is what nodeAffinity targets; the taint is what repels others.

```yaml
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            register-with-taints: "dedicated=argocd:NoSchedule"
            node-labels: "dedicated=argocd"
```

### 2. ArgoCD — toleration + nodeAffinity (`dev/argocd-values.yaml`)

```yaml
global:
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "argocd"
      effect: "NoSchedule"
  affinity:
    nodeAffinity:
      type: hard          # argo-cd chart: hard => requiredDuringSchedulingIgnoredDuringExecution
      matchExpressions:
        - key: dedicated
          operator: In
          values:
            - argocd
```

> Note: `global.affinity.nodeAffinity.type/matchExpressions` is the argo-cd
> chart's custom schema (not raw Kubernetes affinity). `type: hard` renders to
> `requiredDuringSchedulingIgnoredDuringExecution`. `global.*` applies the
> settings to all ArgoCD subcomponents (server, repo-server, application
> controller, redis, etc.).

## Apply

Taint and node-labels are set at cluster-creation time, so recreate the cluster:

```bash
dev/destroy.sh && dev/init.sh
```

## Verification

```bash
# worker3 has the taint and label
kubectl describe node not-so-simple-platform-cluster-dev-worker3 | grep -E 'Taints|dedicated'

# every ArgoCD pod is on worker3
kubectl -n argocd get pods -o wide

# nothing non-ArgoCD landed on worker3
kubectl get pods -A -o wide --field-selector spec.nodeName=not-so-simple-platform-cluster-dev-worker3
```

## Gotchas

- **Toleration without affinity is not enough** — this was the original mistake.
  It permits but does not pin.
- **Affinity without the node label fails scheduling** — a `hard` nodeAffinity
  matching `dedicated=argocd` will leave ArgoCD pods `Pending` if no node carries
  that label. The worker3 `node-labels` entry is mandatory.
- **Capacity:** all ArgoCD components must fit on worker3 alone. If worker3 is
  under-resourced, pods stay `Pending` (nowhere else is allowed).
- Other charts (e.g. kube-prometheus-stack from `dev/init.sh`) have no matching
  toleration, so they correctly stay off worker3.

## References

- argo-cd Helm chart values (global affinity/tolerations): https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- Kubernetes taints & tolerations: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
- Kubernetes node affinity: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
