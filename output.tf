# output "grafana_endpoint" {
#   description = "The endpoint of the Grafana workspace"
#   value       = module.managed_grafana.workspace_endpoint
# }

# output "grafana_api_key" {
#   value     = module.managed_grafana.workspace_service_account_tokens["terraform"].key
#   sensitive = true
# }

# output "grafana_url" {
#   value = module.managed_grafana.workspace_endpoint
# }

# output "security_group_id" {
#   value = module.managed_grafana.security_group_id
# }

# output "workspace_grafana_version" {
#   value = module.managed_grafana.workspace_grafana_version
# }

# output "workspace_arn" {
#   value = module.managed_grafana.workspace_arn
# }

# output "workspace_id" {
#   value = module.managed_grafana.workspace_id
# }

output "workspace_endpoint" {
  value = module.managed_grafana.workspace_endpoint
}

output "service_account_id" {
  value = module.managed_grafana.workspace_service_accounts["terraform"].service_account_id
}

output "workspace_api_keys" {
  value = module.managed_grafana.workspace_api_keys
  sensitive = true
}

output "workspace_service_account_tokens" {
  value = module.managed_grafana.workspace_service_account_tokens
  sensitive = true
}
