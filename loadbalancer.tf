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
  protocol            = "http"
  port                = var.application_port
  path                = "/"
  interval_in_seconds = 5
  probe_threshold     = 2
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