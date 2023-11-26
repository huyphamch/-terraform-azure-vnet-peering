resource "azurerm_virtual_network" "vnet" {
  count               = length(var.location)
  name                = "vnet-${var.prefix}-${count.index}"
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  address_space       = [element(var.vnet_address_space, count.index)]
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
}

resource "azurerm_subnet" "subnet-web" {
  count                = length(var.location)
  name                 = "subnet-web-${var.prefix}-${count.index}"
  resource_group_name  = element(azurerm_resource_group.rg-web.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefixes     = [cidrsubnet(element(var.vnet_address_space, count.index), 4, 0)]
}

resource "azurerm_subnet" "subnet-db" {
  count                = length(var.location)
  name                 = "subnet-db-${var.prefix}-${count.index}"
  resource_group_name  = element(azurerm_resource_group.rg-web.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefixes     = [cidrsubnet(element(var.vnet_address_space, count.index), 4, 15)]
}

# Create Security group and rules for web VM
resource "azurerm_network_security_group" "nsg-web" {
  count               = length(var.location)
  name                = "nsg-web-${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
}

# Associate the NSG with the Subnet
resource "azurerm_subnet_network_security_group_association" "web-nsg-association" {
  count                     = length(var.location)
  subnet_id                 = element(azurerm_subnet.subnet-web.*.id, count.index)
  network_security_group_id = element(azurerm_network_security_group.nsg-web.*.id, count.index)
}

resource "azurerm_network_security_rule" "nsg-rdp-web-rule" {
  count                       = length(var.location)
  name                        = "rdp"
  description                 = "Allow RDP."
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = element(azurerm_resource_group.rg-web.*.name, count.index)
  network_security_group_name = element(azurerm_network_security_group.nsg-web.*.name, count.index)
}

resource "azurerm_network_security_rule" "nsg-ssh-web-rule" {
  count                       = length(var.location)
  name                        = "ssh"
  description                 = "Allow SSH."
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = element(azurerm_resource_group.rg-web.*.name, count.index)
  network_security_group_name = element(azurerm_network_security_group.nsg-web.*.name, count.index)
}

resource "azurerm_network_security_rule" "nsg-http-web-rule" {
  count                       = length(var.location)
  name                        = "http"
  description                 = "Allow HTTP."
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = element(azurerm_resource_group.rg-web.*.name, count.index)
  network_security_group_name = element(azurerm_network_security_group.nsg-web.*.name, count.index)
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "peering" {
  count                        = length(var.location)
  name                         = "peering-to-${element(azurerm_virtual_network.vnet.*.name, 1 - count.index)}"
  resource_group_name          = element(azurerm_resource_group.rg-web.*.name, count.index)
  virtual_network_name         = element(azurerm_virtual_network.vnet.*.name, count.index)
  remote_virtual_network_id    = element(azurerm_virtual_network.vnet.*.id, 1 - count.index)
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}