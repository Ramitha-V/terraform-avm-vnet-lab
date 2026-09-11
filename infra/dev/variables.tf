variable "subscription_id" {
  description = "Azure subscription ID used for the dev deployment."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a 36 character GUID."
  }
}

variable "location" {
  description = "Azure region for the lab resources."
  type        = string
  default     = "centralindia"
}

variable "resource_group_name" {
  description = "Resource group that contains the VNet."
  type        = string
  default     = "rg-avm-vnet-dev"
}

variable "vnet_name" {
  description = "Name of the development VNet."
  type        = string
  default     = "vnet-avm-dev"
}

variable "address_space" {
  description = "VNet CIDR blocks."
  type        = list(string)
  default     = ["10.20.0.0/16"]

  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR block."
  }
}
