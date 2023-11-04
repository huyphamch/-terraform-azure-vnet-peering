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