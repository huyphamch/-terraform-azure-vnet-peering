variable "tenant_id" {
  description = "The tenantId"
  default     = "5067182e-3e4f-403e-bcfb-f3f5d4a34c19"
}

variable "subscription_id" {
  description = "The subscriptionId"
  default     = "9f7feb4a-439a-4294-ab43-1450f2dc7a38"
}

variable "custom_email" {
  description = "Notification email for operator"
  default     = "az104-user@simplilearnhol16.onmicrosoft.com"
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