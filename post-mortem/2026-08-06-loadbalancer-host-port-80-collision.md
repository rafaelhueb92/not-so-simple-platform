# Post-mortem: LoadBalancer container fails to create — host port 80 collision

- **Date:** 2026-08-06
- **Environment:** local dev — KIND cluster (`not-so-simple-platform-cluster-dev`) on macOS (Docker Desktop)
- **Component:** `cloud-provider-kind` LoadBalancer controller + KIND `extraPortMappings`
- **Affected resource:** `Service/hello-service` (`dev/manifest/service.yaml`), `type: LoadBalancer`
- **Severity:** low (local dev only)
- **Status:** resolved
- **Related:** [2026-08-06-cloud-provider-kind-envoy-admin-port.md](./2026-08-06-cloud-provider-kind-envoy-admin-port.md) — the prior error that led to enabling `--enable-lb-port-mapping`

## Summary

After enabling `--enable-lb-port-mapping` (fix from the related post-mortem),
`cloud-provider-kind` failed at a new step — it could no longer even create the
envoy LB container:

```
Error syncing load balancer: failed to ensure load balancer: failed to create
containers kindccm-943dec11da07 [ ... --publish=0.0.0.0:80:80/TCP --publish=10000/TCP
--publish-all docker.io/envoyproxy/envoy:v1.33.2 ... ]
```

Root cause: the KIND control-plane node already published host port 80
(`0.0.0.0:80->80/tcp`) via `extraPortMappings`. `cloud-provider-kind` then tried
to publish the LB on the same host port 80, and Docker rejected the bind.

## Impact

- `hello-service` LoadBalancer never provisioned; no external address in dev.
- No production/staging impact.

## Detection

`SyncLoadBalancerFailed` warning event on `default/hello-service`, with a docker
container-create failure in the `cloud-provider-kind` logs.

## Investigation / Timeline

1. Identified two competing host-exposure strategies both claiming host port 80:

   | Strategy | Where | Wants host port |
   |---|---|---|
   | Ingress-style `extraPortMappings` | `kind-config.yaml` control-plane + `ingress-ready=true` label | 80, 443 |
   | `cloud-provider-kind --enable-lb-port-mapping` | `hello-service` `type: LoadBalancer`, `port: 80` | 80 |

2. Confirmed the control-plane holds port 80:

   ```bash
   docker ps --format '{{.Names}}\t{{.Ports}}' | grep ':80->'
   # not-so-simple-platform-cluster-dev-control-plane  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
   ```

3. Reproduced the exact bind failure:

   ```bash
   docker run --rm -d --publish=0.0.0.0:80:80/TCP alpine sleep 5
   # docker: Error response from daemon: ... Bind for 0.0.0.0:80 failed: port is already allocated
   ```

## Root Cause

Two host-exposure mechanisms were configured for the same host port:

- KIND `extraPortMappings` (80/443) — designed for an **Ingress controller**
  reachable on the host (paired with the `ingress-ready=true` node label).
- `cloud-provider-kind` port-mapping mode — publishes **LoadBalancer** Service
  ports to the host.

Since the cluster uses `type: LoadBalancer` Services (not an Ingress
controller), the `extraPortMappings` were both unused and actively blocking the
LB from binding host port 80.

## Resolution (Option B — remove the ingress port mappings)

Standardized on `type: LoadBalancer` and removed the vestigial ingress
mappings so the LB can own the host ports.

`dev/kind-config.yaml` — control-plane node simplified:

```yaml
# before
- role: control-plane
  kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "ingress-ready=true"
  extraPortMappings:
    - containerPort: 80
      hostPort: 80
      protocol: TCP
    - containerPort: 443
      hostPort: 443
      protocol: TCP

# after
- role: control-plane
```

Because `extraPortMappings` are applied at cluster-creation time, the cluster
must be recreated:

```bash
dev/destroy.sh && dev/init.sh
sudo cloud-provider-kind --enable-lb-port-mapping
```

Host port 80 is now free, so the envoy LB container publishes
`0.0.0.0:80:80` cleanly and `hello-service` gets a working external address.

### Alternative (Option A — not chosen)

Leave `extraPortMappings` in place and change the Service `port` to a free host
port (e.g. `8080`). No cluster recreate, but keeps two host-exposure strategies
around. Rejected in favor of the cleaner single-strategy setup.

## Lessons Learned

- Pick **one** host-exposure strategy per cluster: Ingress-controller
  (`extraPortMappings` + `ingress-ready`) **or** `type: LoadBalancer`
  (`cloud-provider-kind`). Configuring both invites host-port collisions.
- `failed to create containers ... Bind for 0.0.0.0:80 failed: port is already
  allocated` is a host-port ownership problem — check `docker ps` port columns,
  not the manifests.

## References

- cloud-provider-kind: https://github.com/kubernetes-sigs/cloud-provider-kind
- KIND extraPortMappings / ingress: https://kind.sigs.k8s.io/docs/user/ingress/
