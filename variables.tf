variable "prefix" {
  description = "the prefix for all resource names"
  default     = "az104"
}

# Azure variables
variable "location" {
  default = [
    "eastus",
    "eastus2",
  ]
}

variable "vnet_address_space" {
  default = [
    "10.30.0.0/16",
    "172.20.0.0/16"
  ]
}

variable "application_port" {
  description = "Port that you want to expose to the external load balancer"
  default     = 80
}

variable "admin_user" {
  description = "User name to use as the admin account on the VMs that will be part of the VM scale set"
  default     = "adminuser"
}

variable "admin_password" {
  description = "Default password for admin account"
  default     = "Admin+123456"
}

variable "custom_email" {
  description = "Notification email"
  default     = "huy.phamch@gmail.com"
}