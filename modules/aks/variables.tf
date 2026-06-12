variable "name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  description = "Kubernetes version. Pin to a specific version for production stability."
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "Initial number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "node_vm_size" {
  description = "VM size for default node pool."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "subnet_id" {
  description = "Subnet ID for the node pool. The subnet must have sufficient address space."
  type        = string
}

variable "acr_id" {
  description = "ACR resource ID to grant AcrPull access to the cluster identity."
  type        = string
  default     = null
}

variable "enable_auto_scaling" {
  type    = bool
  default = true
}

variable "min_count" {
  type    = number
  default = 1
}

variable "max_count" {
  type    = number
  default = 5
}

variable "tags" {
  type    = map(string)
  default = {}
}