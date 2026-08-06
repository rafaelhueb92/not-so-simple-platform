# Post-mortem: LoadBalancer stuck — "envoy admin port 10000 not found, got map[]"

- **Date:** 2026-08-06
- **Environment:** local dev — KIND cluster (`not-so-simple-platform-cluster-dev`) on macOS (Docker Desktop)
- **Component:** `cloud-provider-kind` LoadBalancer controller
- **Affected resource:** `Service/hello-service` (`dev/manifest/service.yaml`), `type: LoadBalancer`
- **Severity:** low (local dev only, no production impact)
- **Status:** resolved

## Summary

A `type: LoadBalancer` Service never received an external IP. `cloud-provider-kind`
logged:

```
Error syncing load balancer: failed to ensure load balancer: envoy admin port 10000 not found, got map[]
```

Root cause was a **macOS-specific networking requirement**: `cloud-provider-kind`
was started without `--enable-lb-port-mapping`, so the envoy proxy container's
ports were never published to the host. The manifests were correct and not
involved.

## Impact

- `hello-service` had no reachable external LoadBalancer address in local dev.
- No production/staging impact. No data loss.

## Detection

Observed manually via the `cloud-provider-kind` error log while syncing the
LoadBalancer.

## Investigation / Timeline

1. Inspected the manifests (`service.yaml`, `deployment.yaml`,
   `kustomization.yaml`) — all valid. Service selector, ports, and target port
   were correct. Ruled out a manifest issue.
2. Listed containers:

   ```
   kindccm-943dec11da07  envoyproxy/envoy:v1.33.2  Up  80/tcp, 10000/tcp
   ```

   The envoy proxy container was running and *exposed* 10000/tcp — but with no
   `0.0.0.0:xxxx->10000` host mapping.
3. Inspected the container's port bindings:

   ```bash
   docker inspect kindccm-943dec11da07 --format '{{json .NetworkSettings.Ports}}'
   # {"10000/tcp":[],"80/tcp":[]}   ← exposed, NOT published to host
   ```

   Empty binding arrays confirmed the ports were unpublished.

## Root Cause

`cloud-provider-kind`'s `waitLoadBalancerReady` polls the envoy **admin port
(10000)** at `/ready` to know when the LoadBalancer is up. To reach it, the
controller reads the container's host-published port from
`NetworkSettings.Ports`. With no published port, that lookup returns an empty
map — hence `got map[]`.

On **macOS/Windows**, containers run inside a VM and KIND node/container IPs are
**not routable from the host**. `cloud-provider-kind` therefore must run in
port-mapping mode (`--enable-lb-port-mapping`), where it publishes LB ports —
including the 10000 admin port — to the host. On Linux this is unnecessary
because container IPs are directly reachable, which is why the default behavior
does not publish ports.

The controller had been started without the flag.

## Resolution

Restart `cloud-provider-kind` with port mapping enabled:

```bash
# 1. Stop the current instance (Ctrl-C where it's running)

# 2. Remove the stale envoy container so it is recreated with port mappings
docker rm -f kindccm-943dec11da07

# 3. Relaunch with port mapping enabled (sudo needed for privileged host ports)
sudo cloud-provider-kind --enable-lb-port-mapping
# equivalent: ENABLE_LB_PORT_MAPPING=true cloud-provider-kind
```

After relaunch the envoy container is recreated with published ports and
`hello-service` receives a reachable external address.

## Gotchas / Follow-ups

- **Privileged port:** `hello-service` maps `port: 80`, a privileged host port —
  hence `sudo`. Alternatively expose the Service on a high port (e.g. `8080`).
- **Port-80 conflict:** the KIND control-plane node already publishes
  `0.0.0.0:80->80/tcp` (via `extraPortMappings` in the kind cluster config). If
  `cloud-provider-kind` also maps the LB to host port 80, the bind conflicts.
  Fix by either changing the Service `port` to `8080`, or removing the port-80
  `extraPortMappings` from the kind config now that LB port-mapping handles host
  exposure. **TODO:** confirm which approach we standardize on for dev.

## Lessons Learned

- `cloud-provider-kind` behaves differently on macOS vs Linux; the
  `--enable-lb-port-mapping` flag is mandatory on macOS/Windows.
- `envoy admin port 10000 not found, got map[]` is a networking/port-publishing
  symptom, not a manifest error — check `docker inspect ... NetworkSettings.Ports`
  before touching manifests.

## References

- cloud-provider-kind: https://github.com/kubernetes-sigs/cloud-provider-kind
- Envoy proxy config / `waitLoadBalancerReady`: https://deepwiki.com/kubernetes-sigs/cloud-provider-kind/2.3.1-envoy-proxy-configuration
- Issue #157 (container/node IP routing): https://github.com/kubernetes-sigs/cloud-provider-kind/issues/157
