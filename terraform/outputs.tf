# outputs.tf — Root module outputs
# These values are displayed after `terraform apply` and available to CI/CD

output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = module.networking.resource_group_name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "ACR name"
  value       = module.acr.acr_name
}

output "kube_config_raw" {
  description = "Raw kubeconfig for kubectl access"
  value       = module.aks.kube_config_raw
  sensitive   = true
}

output "node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = module.aks.node_resource_group
}
