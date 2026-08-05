# Local Monitoring

See `scripts/deploy-monitoring-local.sh`.

Installs Prometheus + Grafana with auto-discovery of ServiceMonitors.

Use port-forward:

```
kubectl port-forward -n monitoring svc/prom-stack-grafana 3000:80
```

Login: `admin` / `prom-operator`
