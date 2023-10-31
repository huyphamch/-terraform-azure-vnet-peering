variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "az104"
}

# Azure variables
variable "azure_location" {
  description = "Deployment Prefix"
  type        = string
  default     = "eastus"
}

variable "location" {
  default = [
    "eastus",
    "eastus2",
  ]
}

variable "vnet_address_space" {
  default = [
    "10.30.0.0/16",
    "172.20.0.0/16",
  ]
}


variable "azure_vnet_prefix" {
  description = "Azure VNET prefix"
  type        = list(any)
  default     = ["10.30.0.0/16"]
}

variable "azure_web_subnet_prefix" {
  description = "Azure Test Web VM Subnet Prefix"
  type        = list(any)
  default     = ["10.30.0.0/24"]
}

variable "azure_db_subnet_prefix" {
  description = "Azure Test DB Subnet Prefix"
  type        = list(any)
  default     = ["10.30.1.0/24"]
}

variable "azure_vnet2_prefix" {
  description = "Azure VNET 2 prefix"
  type        = list(any)
  default     = ["172.20.0.0/16"]
}

variable "azure_web2_subnet_prefix" {
  description = "Azure Web VM VNET 2 Subnet Prefix"
  type        = list(any)
  default     = ["172.20.0.0/24"]
}