output "grafana_endpoint" {
  description = "The endpoint of the Grafana workspace"
  value       = module.managed_grafana.workspace_endpoint
}
