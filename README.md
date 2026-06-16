# Terraform Azure Module Library with HCP Vault & Terraform Cloud

**Author:** Jane Buro  
**GitHub Org:** janebjobtech-cloud  
**Difficulty:** Intermediate-Advanced  
**Status:** Complete — v1.1.3 live in Terraform Cloud Private Registry

---

## What I Built

A private Terraform module library published to a Terraform Cloud registry, with HashiCorp Vault issuing dynamic Azure credentials to the pipeline via GitHub Actions OIDC — no static credentials stored anywhere in the repository.

When a version tag is pushed, the pipeline authenticates to Vault using a short-lived GitHub OIDC token, Vault creates a temporary Azure service principal scoped to the pipeline run, validates all three modules, and publishes the new version to the Terraform Cloud private registry. The service principal is revoked automatically when its TTL expires.

---

## The Business Problem I Solved

When every team writes their own Terraform from scratch, infrastructure drifts. One team's VNet has different address spaces. Another team's AKS cluster has inconsistent security settings. The AzureRM provider version gets updated team by team, years apart.

A module library solves this by giving teams pre-built, tested, opinionated building blocks. Instead of writing 200+ lines of Terraform to deploy an AKS cluster, a team calls my module with five variables and gets a cluster that meets all organizational security and naming standards automatically.

The Vault integration solves a second problem: static Azure credentials in GitHub secrets are a permanent attack surface. Any repository admin can read them, they never expire, and rotating them is a manual process. With Vault's JWT auth method, the pipeline authenticates using GitHub's OIDC token — a cryptographically signed, short-lived token tied to a specific repository and workflow run. Vault issues Azure credentials at runtime that expire when the job ends.

---

## Repository Structure
terraform-azure-modules/

├── modules/

│   ├── vnet/                    ← Azure Virtual Network module

│   │   ├── main.tf

│   │   ├── variables.tf

│   │   └── outputs.tf

│   ├── acr/                     ← Azure Container Registry module

│   │   ├── main.tf

│   │   ├── variables.tf

│   │   └── outputs.tf

│   └── aks/                     ← Azure Kubernetes Service module

│       ├── main.tf

│       ├── variables.tf

│       └── outputs.tf

├── examples/

│   └── complete/                ← Example calling all three modules together

│       └── main.tf

├── vault-infra/                 ← Terraform-managed Vault configuration

│   ├── main.tf

│   └── variables.tf

└── .github/workflows/

├── validate.yml             ← Runs on every pull request

└── publish.yml              ← Tags and publishes to Terraform Cloud registry


---

## Module Reference

### VNet Module

Creates an Azure Virtual Network with a dynamic subnet map.

```hcl
module "vnet" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "vnet-production"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
  subnets = {
    "snet-aks"  = "10.0.1.0/24"
    "snet-misc" = "10.0.2.0/24"
  }
}
```

**Outputs:** `vnet_id`, `vnet_name`, `subnet_ids`

---

### ACR Module

Creates an Azure Container Registry with SKU validation and admin user disabled by default.

```hcl
module "acr" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "acrproduction"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
}
```

**Outputs:** `acr_id`, `acr_name`, `login_server`

---

### AKS Module

Creates an AKS cluster with SystemAssigned managed identity, Azure CNI networking, Azure AD RBAC, auto-scaling, and automatic AcrPull role assignment.

```hcl
module "aks" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "aks-production"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  subnet_id           = module.vnet.subnet_ids["snet-aks"]
  acr_id              = module.acr.acr_id
  enable_auto_scaling = true
  min_count           = 1
  max_count           = 5
}
```

**Outputs:** `cluster_id`, `cluster_name`, `kube_config` (sensitive), `kubelet_identity_object_id`

---

## Pipeline Architecture

### validate.yml — Pull Request Gate

Triggers on every pull request targeting `main`. Uses a matrix strategy to run three parallel jobs — one per module — each executing `terraform fmt -check`, `terraform init`, and `terraform validate`. Nothing reaches `main` without passing all three checks across all three modules.

### publish.yml — Tag-Triggered Publishing

Triggers when a version tag matching `v*.*.*` is pushed. Executes five steps:

1. **GitHub OIDC authentication to Vault** — short-lived cryptographically signed token validated by Vault JWT auth backend
2. **Dynamic Azure credential retrieval** — Vault creates a temporary Azure service principal; credentials expire when TTL ends
3. **Module validation** — all three modules initialized and validated using dynamic credentials
4. **Terraform Cloud publishing** — calls Terraform Cloud API to register the new module version
5. **Automatic credential revocation** — Vault revokes the service principal when the lease expires

---

## Security Design

| Control | Implementation |
|---|---|
| No static Azure credentials | Dynamic SP issued by Vault per pipeline run |
| OIDC-based authentication | GitHub JWT token validated cryptographically by Vault |
| Repository-scoped access | Vault JWT role bound to exact repo using glob pattern |
| Least-privilege secrets | ACL policy allows only `azure/creds/github-actions-role` reads |
| Credential TTL | 1-hour TTL, 2-hour max; revoked automatically on expiry |
| Admin user disabled | ACR module sets `admin_enabled = false` by default |
| SKU validation | ACR module rejects invalid SKU at plan time |
| No tfvars in version control | `.gitignore` excludes `*.tfvars`, `*.tfstate`, `.terraform/` |

---

## Verification Checklist

- Terraform Cloud organization has `azure-modules` published in private registry
- Vault JWT auth method configured and accepting GitHub OIDC tokens
- Vault Azure secrets engine issuing dynamic credentials
- `validate.yml` runs on pull requests and checks all three modules
- Version tag push triggers `publish.yml` successfully
- Dynamic Azure credentials retrieved from Vault during pipeline run
- Module version `1.1.3` live in Terraform Cloud private registry

---

## Troubleshooting

| Error | Cause | Resolution |
|---|---|---|
| `invalid audience (aud) claim` | `jwtGithubAudience` mismatch | Ensure `jwtGithubAudience` in workflow matches `bound_audiences` in Vault JWT role |
| `claim "sub" does not match` | Vault JWT role bound to branch ref, not tag ref | Update `bound_claims` to use glob: `repo:org/repo:*` |
| `Insufficient privileges` | Vault SP missing Azure AD permissions | Grant `Application.ReadWrite.All` and `Directory.ReadWrite.All` with admin consent |
| `Resource does not exist` | Azure AD replication delay | Set `application_object_id` on Vault Azure role to use pre-existing app |
| `enable_auto_scaling not expected` | AzureRM provider v4 breaking change | Replace with `auto_scaling_enabled` |
| Module not found in Terraform Cloud | Wrong source path | Confirm module appears under correct org name in registry |

---

## Interview Talking Points

Lead with: "I built a private Terraform module library published to Terraform Cloud, with HashiCorp Vault issuing dynamic Azure credentials to the pipeline via OIDC. No Azure credentials are stored in GitHub secrets — Vault creates a service principal at the start of each run and revokes it when it expires."

Be ready to explain:
- What a Terraform module registry does and why teams use it instead of copying Terraform code
- How Vault JWT authentication works with GitHub OIDC and why it's more secure than static secrets
- Why dynamic credentials are more secure than static service principals in GitHub secrets
- The difference between `terraform validate` and `terraform plan`, and why validate runs on PRs
- How the `bound_claims` glob pattern scopes Vault access to a specific repository
- Why `application_object_id` eliminates Azure AD replication delays in dynamic credential generation

---

## Repository Description

*Reusable Azure Terraform module library (VNet, ACR, AKS) published to a private Terraform Cloud registry, with HashiCorp Vault issuing dynamic Azure credentials via GitHub Actions OIDC. No static credentials. No manual publishing. Push a tag, get a module version.*