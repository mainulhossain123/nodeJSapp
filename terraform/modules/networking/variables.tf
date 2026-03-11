# networking/variables.tf

variable "resource_group_name" {
  description = "Name prefix for the resource group"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network"
  type        = list(string)
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
}
