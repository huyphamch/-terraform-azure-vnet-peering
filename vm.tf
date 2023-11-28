
# Use Auto-Scaling to create Virtual Machines (VM) with web-server for public Web
# resource "azurerm_windows_virtual_machine_scale_set" "scale" {
resource "azurerm_linux_virtual_machine_scale_set" "scale" {
  count                           = length(var.location)
  name                            = "vmss-${var.prefix}-${count.index}"
  location                        = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name             = element(azurerm_resource_group.rg-web.*.name, count.index)
  sku                             = "Standard_D2s_v3"
  instances                       = 2
  computer_name_prefix            = "web-${var.prefix}-${count.index}"
  admin_username                  = var.admin_user
  admin_password                  = var.admin_password
  disable_password_authentication = false                          # Linux only
  custom_data                     = base64encode(file("web.conf")) # Linux only

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  /*   source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  } */

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
      # public_ip_address {
      #   name                    = "pip-web-${var.prefix}-${count.index}"
      #   idle_timeout_in_minutes = 15
      # }
    }
  }
}

/* resource "azurerm_virtual_machine_scale_set_extension" "iis_vmss_extension" {
  count                        = length(var.location)
  name                         = "iis-ext-${var.prefix}-${count.index}"
  virtual_machine_scale_set_id = element(azurerm_windows_virtual_machine_scale_set.scale.*.id, count.index)
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.9"
  settings                     = <<SETTINGS
    {
      "commandToExecute": "powershell.exe Install-WindowsFeature -Name Web-Server -IncludeManagementTools"
    }
    SETTINGS
} */

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

resource "azurerm_windows_virtual_machine" "jumpbox" {
  #resource "azurerm_linux_virtual_machine" "vm-db" {
  count               = length(var.location)
  name                = "jb-${var.prefix}-${count.index}"
  location            = element(var.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  size                = "Standard_D2s_v3"

  admin_username = var.admin_user
  admin_password = var.admin_password
  # disable_password_authentication = false # Linux only

  network_interface_ids = [element(azurerm_network_interface.jumpbox.*.id, count.index)]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  /*   source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  } */

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

# Create Virtual Machine (VM) for private Database
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

resource "azurerm_windows_virtual_machine" "vm-db" {
  #resource "azurerm_linux_virtual_machine" "vm-db" {
  count               = length(var.location)
  name                = "vm-db-${var.prefix}-${count.index}"
  location            = element(azurerm_resource_group.rg-web.*.location, count.index)
  resource_group_name = element(azurerm_resource_group.rg-web.*.name, count.index)
  size                = "Standard_D2s_v3"

  admin_username = var.admin_user
  admin_password = var.admin_password
  # disable_password_authentication = false # Linux only

  network_interface_ids = [
    element(azurerm_network_interface.nic-db.*.id, count.index),
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  /*   source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  } */

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}