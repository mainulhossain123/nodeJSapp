# aks/main.tf — AKS Cluster with enterprise-grade configuration

# User-Assigned Managed Identity for AKS control plane
# Why managed identity over service principal:
#   - No password rotation needed
#   - Azure handles credential lifecycle automatically
#   - Least-privilege: only assigned roles it needs
resource "azurerm_user_assigned_identity" "aks" {
  name                = "mi-aks-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

# Grant AKS identity permission to pull from ACR
# Role: "AcrPull" — read-only access to pull container images
# Without this: AKS nodes get ImagePullBackOff errors
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Grant AKS identity permissions on its subnet (required for CNI networking)
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.aks_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# Log Analytics Workspace — for Azure Monitor / Container Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-nodejs-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "production" ? 90 : 30
  tags                = var.tags
}

# AKS Cluster — the core resource
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-nodejs-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-nodejs-${var.environment}"
  kubernetes_version  = var.kubernetes_version

  # Private cluster: API server has no public endpoint in production
  private_cluster_enabled = var.environment == "production" ? true : false

  # System Node Pool — runs Kubernetes system components
  # CRITICAL: taint system pool with CriticalAddonsOnly
  # This prevents user workloads from landing on system nodes
  default_node_pool {
    name                = "systempool"
    node_count          = var.aks_system_node_count
    vm_size             = var.aks_system_vm_size
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 64
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    zones               = length(var.node_pool_zones) > 0 ? var.node_pool_zones : null
    max_pods            = 110

    # Taint: only system-critical addons (CoreDNS, metrics-server) can schedule here
    only_critical_addons_enabled = true

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }

    upgrade_settings {
      max_surge = "33%"
    }

    tags = var.tags
  }

  # Managed Identity for control plane
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Azure CNI networking (vs kubenet)
  # Why Azure CNI: pods get real VNet IPs, NSGs work at pod level
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    dns_service_ip    = "10.0.64.10"
    service_cidr      = "10.0.64.0/19"
    load_balancer_sku = "standard"
  }

  # Azure Monitor Container Insights
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Azure Key Vault Secrets Store CSI Driver
  # Allows pods to mount Key Vault secrets as files/env vars
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Azure Active Directory RBAC integration
  # managed = true is deprecated in 3.x (defaults to true in 4.0) but still required
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # OIDC Issuer — required for Workload Identity and AAD pod-managed identity
  oidc_issuer_enabled = true

  # Auto-upgrade channel: "patch" — automatically apply patch-level K8s upgrades
  automatic_channel_upgrade = "patch"

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [0, 1, 2, 3, 4]
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }
}

# User Node Pool — where our application workloads run
# Separated from system pool: prevents noisy-neighbor issues
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.aks_user_vm_size
  vnet_subnet_id        = var.aks_subnet_id
  os_disk_size_gb       = 128
  os_disk_type          = "Managed"

  # Cluster Autoscaler enabled
  enable_auto_scaling = true
  min_count           = var.aks_min_node_count
  max_count           = var.aks_max_node_count

  # HA across availability zones (null disables AZ pinning when not supported)
  zones = length(var.node_pool_zones) > 0 ? var.node_pool_zones : null

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
    "workload-type" = "application"
  }

  # Taint: only pods that tolerate "workload=application" land here
  node_taints = ["workload=application:NoSchedule"]

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags
}
