variable "tenant_id" {
  description = "The tenantId"
  default     = "3943a345-5add-4713-9c9f-afa8753efe4c"
}

variable "subscription_id" {
  description = "The subscriptionId"
  default     = "da84ea64-e680-406d-90d1-c11693830e14"
}

variable "custom_email" {
  description = "Notification email for onboarded user"
  default     = "az104-user@simplilearnhol44.onmicrosoft.com"
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