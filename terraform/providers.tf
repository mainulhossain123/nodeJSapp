# providers.tf — Configure the AzureRM provider

provider "azurerm" {
  # skip_provider_registration: the azurerm provider attempts to auto-register
  # ~100 resource providers on first run. Several deprecated namespaces
  # (Microsoft.TimeSeriesInsights, Microsoft.MixedReality, Microsoft.Media)
  # no longer exist in Azure and cause a 404 error. Skipping auto-registration
  # is safe — Azure auto-registers providers the moment you actually deploy
  # a resource that needs them.
  skip_provider_registration = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  # Auth: Uses ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
  # In CI/CD: these come from GitHub Secrets
  # Locally: use `az login` + `az account set --subscription <id>`
}

provider "kubernetes" {
  host                   = module.aks.kube_config_host
  client_certificate     = base64decode(module.aks.kube_config_client_certificate)
  client_key             = base64decode(module.aks.kube_config_client_key)
  cluster_ca_certificate = base64decode(module.aks.kube_config_cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kube_config_host
    client_certificate     = base64decode(module.aks.kube_config_client_certificate)
    client_key             = base64decode(module.aks.kube_config_client_key)
    cluster_ca_certificate = base64decode(module.aks.kube_config_cluster_ca_certificate)
  }
}
