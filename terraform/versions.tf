# versions.tf — Pin all provider versions for reproducibility
# In enterprise, you NEVER use unpinned versions (breaks on provider updates)

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # ~> 3.85 (no trailing .0) = any 3.85+ up to <4.0.0
      # 3.85.0 used AKS API version 2023-04-02-preview which Azure removed.
      # The latest 3.x uses supported API versions (2024+).
      version = "~> 3.85"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }

  # Remote backend: Azure Blob Storage for state
  # CRITICAL: Never use local state in teams/CI — race conditions + no locking
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraform7c2609bf"
    container_name       = "tfstate"
    key                  = "nodejs-aks/terraform.tfstate"
    # State locking: Azure Blob provides automatic lease-based locking
  }
}
