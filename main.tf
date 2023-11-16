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
  tenant_id       = "fb309cc9-571c-4cd9-a657-5c973d68ea74"
  subscription_id = "9beb4f20-2de1-408f-820a-9c00d375cc0b"
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
  address_prefixes     = [cidrsubnet(element(var.vnet_address_space, count.index), 4, 0)]
}

resource "azurerm_subnet" "subnet-db" {
  count                = length(var.location)
  name                 = "subnet-db-${var.prefix}-${count.index}"
  resource_group_name  = element(azurerm_resource_group.rg-web.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefixes     = [cidrsubnet(element(var.vnet_address_space, count.index), 4, 15)]
}

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

# Create load balancer with public IP
resource "azurerm_public_ip" "lbpip" {
  count               = length(var.location)
  name                = "lb-pip-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-${var.prefix}-${count.index}"
}

resource "azurerm_lb" "lb" {
  count               = length(var.location)
  name                = "lb-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = element(azurerm_public_ip.lbpip.*.id, count.index)

  }
}

# Incorporate a simple health probe to make sure the web servers in the backend pool are responding and healthy
resource "azurerm_lb_backend_address_pool" "bpepool" {
  count           = length(var.location)
  loadbalancer_id = element(azurerm_lb.lb.*.id, count.index)
  name            = "bpepool-${var.prefix}-${count.index}"
}

resource "azurerm_lb_probe" "probe" {
  count               = length(var.location)
  loadbalancer_id     = element(azurerm_lb.lb.*.id, count.index)
  name                = "probe-${var.prefix}-${count.index}"
  port                = var.application_port
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lbnatrule" {
  count                          = length(var.location)
  loadbalancer_id                = element(azurerm_lb.lb.*.id, count.index)
  name                           = "LBPortMapping"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  backend_address_pool_ids       = [element(azurerm_lb_backend_address_pool.bpepool.*.id, count.index)]
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = element(azurerm_lb_probe.probe.*.id, count.index)
}

# Use Auto-Scaling to create Virtual Machines (VM) for public Web
resource "azurerm_linux_virtual_machine_scale_set" "scale" {
  count                           = length(var.location)
  name                            = "vmss-${var.prefix}-${count.index}"
  location                        = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name             = element(azurerm_resource_group.rg-web.*.name, count.index)
  sku                             = "Standard_D2s_v3"
  instances                       = 2
  computer_name_prefix            = "web-${var.prefix}"
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password
  disable_password_authentication = false
  custom_data                     = base64encode(file("web.conf"))

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "nic-web-${var.prefix}-${count.index}"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      primary                                = true
      subnet_id                              = element(azurerm_subnet.subnet-web.*.id, count.index)
      load_balancer_backend_address_pool_ids = [element(azurerm_lb_backend_address_pool.bpepool.*.id, count.index)]
      public_ip_address {
        name                    = "pip-web-${var.prefix}-${count.index}"
        idle_timeout_in_minutes = 15
      }
    }
  }
}

# Configure Auto-Scaling thresholds to scale in or out
resource "azurerm_monitor_autoscale_setting" "vmss" {
  count               = length(var.location)
  name                = "vmss-mon-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  target_resource_id  = element(azurerm_linux_virtual_machine_scale_set.scale.*.id, count.index)

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 2
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = element(azurerm_linux_virtual_machine_scale_set.scale.*.id, count.index)
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = element(azurerm_linux_virtual_machine_scale_set.scale.*.id, count.index)
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = [var.custom_email]
    }
  }
}

# Create jump-server as public VMs to access internal VMs
resource "azurerm_public_ip" "jumpbox" {
  count               = length(var.location)
  name                = "jb-pip-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}-${var.prefix}-${count.index}-ssh"
}

resource "azurerm_network_interface" "jumpbox" {
  count               = length(var.location)
  name                = "jb-nic-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = element(azurerm_subnet.subnet-web.*.id, count.index)
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.jumpbox.*.id, count.index)
  }
}

resource "azurerm_virtual_machine" "jumpbox" {
  count                 = length(var.location)
  name                  = "jb-${var.prefix}-${count.index}"
  location              = element(var.location, count.index)
  resource_group_name   = element(azurerm_resource_group.rg-web.*.name, count.index)
  network_interface_ids = [element(azurerm_network_interface.jumpbox.*.id, count.index)]
  vm_size               = "Standard_D2s_v3"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "jumpbox-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "jumpbox-${var.prefix}-${count.index}"
    admin_username = var.admin_user
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
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
  name                        = "ssh"
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

resource "azurerm_network_interface" "nic-db" {
  count               = length(var.location)
  name                = "nic-db-${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)

  ip_configuration {
    name                          = "internal"
    subnet_id                     = element(azurerm_subnet.subnet-db.*.id, count.index)
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Virtual Machine (VM) for private Database
resource "azurerm_linux_virtual_machine" "vm-db" {
  count               = length(var.location)
  name                = "vm-db-${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  size                = "Standard_D2s_v3"

  admin_username                  = var.admin_user
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    element(azurerm_network_interface.nic-db.*.id, count.index),
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
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