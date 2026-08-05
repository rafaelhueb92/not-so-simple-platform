output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_connection_commands" {
  value = module.eks.cluster_connection_commands
}

output "grafana_workspace_endpoint" {
  description = "Managed Grafana workspace endpoint URL. Null unless enable_managed_monitoring is true."
  value       = module.eks.grafana_workspace_endpoint
}