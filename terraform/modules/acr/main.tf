# acr/main.tf — Azure Container Registry (private, production-grade)

# Use the subscription ID to generate a deterministic, globally-unique ACR name.
# First 8 chars of a subscription ID are always hex (a-f, 0-9) — safe for ACR naming.
# This means the name is predictable and never needs to be stored as a secret.
data "azurerm_client_config" "current" {}

locals {
  # Strip hyphens from subscription ID and take first 8 chars
  # e.g. "7c2609bf-1b4b-..." → "7c2609bf" → acrnodejsstaging7c2609bf
  acr_suffix = substr(replace(data.azurerm_client_config.current.subscription_id, "-", ""), 0, 8)
}

resource "azurerm_container_registry" "main" {
  name                = "acrnodejs${var.environment}${local.acr_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.acr_sku

  # Disable public network access in production — images only accessible via private endpoint
  public_network_access_enabled = var.environment == "production" ? false : true

  # Admin account disabled — use managed identity for authentication
  admin_enabled = false

  # Retention policy: auto-delete untagged manifests after 7 days
  # Only supported on Premium SKU — guard with a dynamic block
  dynamic "retention_policy" {
    for_each = var.acr_sku == "Premium" ? [1] : []
    content {
      days    = 7
      enabled = true
    }
  }

  tags = var.tags
}

# Private Endpoint: ACR accessible only from within our VNet
# In production, nodes pull images via private IP — never via public internet
resource "azurerm_private_endpoint" "acr" {
  count               = var.environment == "production" ? 1 : 0
  name                = "pe-acr-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoints_subnet_id

  private_service_connection {
    name                           = "psc-acr-${var.environment}"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  tags = var.tags
}
