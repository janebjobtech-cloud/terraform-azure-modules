terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }
}

provider "vault" {
  address = var.vault_address
}

resource "vault_jwt_auth_backend" "github_actions" {
  path               = "jwt"
  type               = "jwt"
  bound_issuer       = "https://token.actions.githubusercontent.com"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  description        = "GitHub Actions OIDC authentication"
}

resource "vault_policy" "github_actions_azure" {
  name   = "github-actions-azure"
  policy = <<-EOT
    path "azure/creds/github-actions-role" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_jwt_auth_backend_role" "github_actions_azure" {
  backend        = vault_jwt_auth_backend.github_actions.path
  role_name      = "github-actions-azure"
  role_type      = "jwt"
  token_policies = [vault_policy.github_actions_azure.name]
  token_ttl      = 3600
  bound_audiences = ["https://vault.hashicorp.com"]
  bound_claims = {
    sub = "repo:janebjobtech-cloud/terraform-azure-modules:ref:refs/heads/master"
  }
  user_claim = "sub"
}

resource "vault_azure_secret_backend" "azure" {
  path            = "azure"
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.vault_sp_client_id
  client_secret   = var.vault_sp_client_secret
  description     = "Dynamic Azure credentials for GitHub Actions"
}

resource "vault_azure_secret_backend_role" "github_actions" {
  backend = vault_azure_secret_backend.azure.path
  role    = "github-actions-role"
  ttl     = "1h"
  max_ttl = "2h"
  azure_roles {
    role_name = "Contributor"
    scope     = "/subscriptions/${var.azure_subscription_id}"
  }
}