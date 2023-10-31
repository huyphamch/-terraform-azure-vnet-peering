# Azure Provider source and version being used
terraform {
  required_version = ">= 0.14.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.2"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  tenant_id       = "e2edce3b-5259-4679-9335-940f37afa5e4"
  subscription_id = "4bdb238c-14b9-4485-b7e9-52e890fe3321"
  features {}
}

resource "azurerm_resource_group" "rg-web" {
  count    = length(var.location)
  name     = "rg-global-vnet-peering-${count.index}"
  location = element(var.location, count.index)
}

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
  address_prefixes = [
    cidrsubnet(
      element(
        azurerm_virtual_network.vnet[count.index].address_space,
        count.index,
      ),
      13,
      0,
    ) # /29
  ]
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

# Create Security group and rules for web VM
resource "azurerm_network_security_group" "nsg-web" {
  count               = length(var.location)
  name                = "nsg-web-${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
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

resource "azurerm_network_security_rule" "nsg-icmp-web-rule" {
  count                       = length(var.location)
  name                        = "icmp"
  description                 = "Allow ICMP for AWS VPC resources"
  priority                    = 102
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = element(azurerm_resource_group.rg-web.*.name, count.index)
  network_security_group_name = element(azurerm_network_security_group.nsg-web.*.name, count.index)
}

# Create Virtual Machine (VM) for public Web
resource "azurerm_windows_virtual_machine_scale_set" "scale" {
  count               = length(var.location)
  name                = "sc${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  sku                 = "Standard_D2s_v3"
  instances           = 2
  admin_username      = "adminuser"
  admin_password      = "Admin+123456"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-web-${var.prefix}-${count.index}"
    primary = true
    # Apply Security group rules on network interface of VM
    network_security_group_id = element(azurerm_network_security_group.nsg-web.*.id, count.index)

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = element(azurerm_subnet.subnet-web.*.id, count.index)
      public_ip_address {
        name                    = "pip-web-${var.prefix}-${count.index}"
        idle_timeout_in_minutes = 15
      }
    }
  }
}