variable "name" {
  description = "Name of the container registry. Must be globally unique, alphanumeric only."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  description = "SKU tier. Basic for labs, Standard for production, Premium for geo-replication."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "admin_enabled" {
  description = "Enable admin user. Disabled by default — use Managed Identity or service principals instead."
  type        = bool
  default     = false
}

variable "georeplications" {
  description = "List of regions to geo-replicate to. Requires Premium SKU."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}