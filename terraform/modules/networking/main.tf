# networking/main.tf — VNet, Subnets, NSGs

# Resource Group — everything lives inside this
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# Virtual Network — isolated network space for our AKS cluster
resource "azurerm_virtual_network" "main" {
  name                = "vnet-nodejs-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Subnet for AKS Nodes — where the VMs (nodes) physically reside
resource "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  # /24 = 251 usable IPs (5 reserved by Azure) = enough for ~250 nodes
}

# Subnet for Private Endpoints (ACR, Key Vault)
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.6.0/24"]

  # Private endpoint network policies must be disabled on this subnet
  private_endpoint_network_policies_enabled = false
}

# Network Security Group for AKS nodes
resource "azurerm_network_security_group" "aks_nodes" {
  name                = "nsg-aks-nodes-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Rule: Allow HTTPS from Load Balancer (AKS API server communication)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Rule: Allow kubelet communication between nodes (required by AKS)
  security_rule {
    name                       = "AllowKubelet"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

# Associate NSG with the AKS nodes subnet
resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}
