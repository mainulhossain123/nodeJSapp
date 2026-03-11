# main.tf — Root module — wires all child modules together
# This is the entry point for `terraform plan` and `terraform apply`

locals {
  # Merge environment tag into all tags
  common_tags = merge(var.tags, {
    environment = var.environment
  })
}

# ─── Module: Networking ────────────────────────────────────────────────────────
# Creates: Resource Group, VNet, Subnets, NSGs
module "networking" {
  source = "./modules/networking"

  resource_group_name = var.resource_group_name
  environment         = var.environment
  location            = var.location
  vnet_address_space  = var.vnet_address_space
  tags                = local.common_tags
}

# ─── Module: Azure Container Registry ─────────────────────────────────────────
# Creates: ACR + optional Private Endpoint (production only)
module "acr" {
  source = "./modules/acr"

  resource_group_name         = module.networking.resource_group_name
  location                    = module.networking.resource_group_location
  environment                 = var.environment
  acr_sku                     = var.acr_sku
  private_endpoints_subnet_id = module.networking.private_endpoints_subnet_id
  tags                        = local.common_tags

  depends_on = [module.networking]
}

# ─── Module: Azure Kubernetes Service ──────────────────────────────────────────
# Creates: Managed Identity, AKS Cluster, System+User Node Pools, Log Analytics
module "aks" {
  source = "./modules/aks"

  resource_group_name   = module.networking.resource_group_name
  location              = module.networking.resource_group_location
  environment           = var.environment
  kubernetes_version    = var.kubernetes_version
  aks_system_node_count = var.aks_system_node_count
  aks_system_vm_size    = var.aks_system_vm_size
  aks_user_vm_size      = var.aks_user_vm_size
  aks_min_node_count    = var.aks_min_node_count
  aks_max_node_count    = var.aks_max_node_count
  aks_subnet_id         = module.networking.aks_nodes_subnet_id
  acr_id                = module.acr.acr_id
  node_pool_zones       = var.node_pool_zones
  tags                  = local.common_tags

  depends_on = [module.networking, module.acr]
}

# ─── GitHub Actions CI/CD: AKS RBAC permissions ────────────────────────────────
# The AKS cluster uses Azure AD RBAC (azure_rbac_enabled = true).
# The GitHub Actions SP needs "Azure Kubernetes Service RBAC Cluster Admin"
# on the cluster scope so it can create namespaces, deployments, secrets, etc.
# This block is a no-op when github_actions_sp_object_id is not set.
resource "azurerm_role_assignment" "github_actions_aks_admin" {
  count                = var.github_actions_sp_object_id != "" ? 1 : 0
  principal_id         = var.github_actions_sp_object_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  scope                = module.aks.cluster_id

  depends_on = [module.aks]
}
