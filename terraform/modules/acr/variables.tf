# acr/variables.tf

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

variable "acr_sku" {
  description = "ACR SKU tier"
  type        = string
  default     = "Premium"
}

variable "private_endpoints_subnet_id" {
  description = "Subnet ID for private endpoints"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
}
