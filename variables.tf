variable "tenant_id" {
  description = "The tenantId"
  default     = "22e78c52-ef6d-4aba-a5c0-8da671ad5825"
}

variable "subscription_id" {
  description = "The subscriptionId"
  default     = "e6e2bb59-b77e-4da8-a43f-e170a44ee6f6"
}

variable "custom_email" {
  description = "Notification email for onboarded user"
  default     = "az104-user@simplilearnhol50.onmicrosoft.com"
}

variable "prefix" {
  description = "the prefix for all resource names"
  default     = "104"
}

# Azure variables
variable "location" {
  default = [
    "eastus",
    "eastus",
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