# variables.tf — All configurable inputs (NO hardcoded values in main.tf)

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
  # eastus2: cheaper than eastus, same SLA, good AKS availability zone support
}

variable "resource_group_name" {
  description = "Name of the primary resource group"
  type        = string
  default     = "rg-nodejs-aks"
}

variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
  # /16 = 65,536 addresses — ample for scaling
}

variable "aks_system_node_count" {
  description = "Initial node count for system node pool"
  type        = number
  default     = 1
  # System pool runs: kube-system, CoreDNS, metrics-server
  # Minimum 1 for dev, 3 for production (HA across zones)
}

variable "aks_system_vm_size" {
  description = "VM size for AKS system node pool"
  type        = string
  default     = "Standard_D2s_v3"
  # 2 vCPU, 8GB RAM — adequate for system workloads
}

variable "aks_user_vm_size" {
  description = "VM size for AKS user (application) node pool"
  type        = string
  default     = "Standard_D4s_v3"
  # 4 vCPU, 16GB RAM — application workloads
}

variable "aks_min_node_count" {
  description = "Minimum nodes in user node pool (autoscaler)"
  type        = number
  default     = 2
  # Minimum 2 ensures high availability
}

variable "aks_max_node_count" {
  description = "Maximum nodes in user node pool (autoscaler)"
  type        = number
  default     = 10
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
  # Always pin K8s version — auto-upgrades can break workloads
}

variable "acr_sku" {
  description = "Azure Container Registry SKU"
  type        = string
  default     = "Premium"
  # Premium: required for Private Endpoints, geo-replication, content trust
}

variable "node_pool_zones" {
  description = "Availability zones for AKS node pools. Set to [] for VM sizes/tiers that don't support AZs."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags applied to all Azure resources"
  type        = map(string)
  default = {
    project     = "nodejs-aks"
    managed_by  = "terraform"
    team        = "devops"
  }
}
