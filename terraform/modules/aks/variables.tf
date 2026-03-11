# aks/variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
}

variable "aks_system_node_count" {
  description = "Initial node count for system pool"
  type        = number
}

variable "aks_system_vm_size" {
  description = "VM size for system node pool"
  type        = string
}

variable "aks_user_vm_size" {
  description = "VM size for user node pool"
  type        = string
}

variable "aks_min_node_count" {
  description = "Minimum nodes in user pool"
  type        = number
}

variable "aks_max_node_count" {
  description = "Maximum nodes in user pool"
  type        = number
}

variable "aks_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "acr_id" {
  description = "ID of the Azure Container Registry"
  type        = string
}

variable "node_pool_zones" {
  description = "Availability zones for node pools. Set to [] for VM sizes that don't support AZs (e.g. B-series on Free tier)."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
}
