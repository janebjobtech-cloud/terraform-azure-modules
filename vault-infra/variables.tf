variable "vault_address" {
  description = "Vault server URL."
  type        = string
}

variable "github_org" {
  description = "Your GitHub organization or username."
  type        = string
}

variable "github_repo" {
  description = "Repository name for the terraform-azure-modules repo."
  type        = string
  default     = "terraform-azure-modules"
}

variable "azure_subscription_id" {
  type      = string
  sensitive = true
}

variable "azure_tenant_id" {
  type      = string
  sensitive = true
}

variable "vault_sp_client_id" {
  description = "Client ID of the SP Vault uses to create dynamic credentials."
  type        = string
  sensitive   = true
}

variable "vault_sp_client_secret" {
  description = "Client secret of the SP Vault uses to create dynamic credentials."
  type        = string
  sensitive   = true
}