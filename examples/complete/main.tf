terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  cloud {
    organization = "JaneBuro_JobTech"
    workspaces {
      name = "azure-modules-example"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rg-modules-example"
  location = "East US"
}

module "vnet" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["10.0.0.0/16"]
  subnets = {
    "snet-aks"  = "10.0.1.0/24"
    "snet-misc" = "10.0.2.0/24"
  }
}

module "acr" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "acrexamplemodule"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
}

module "aks" {
  source  = "app.terraform.io/JaneBuro_JobTech/azure-modules/azurerm"
  version = "~> 1.0"

  name                = "aks-example"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  subnet_id           = module.vnet.subnet_ids["snet-aks"]
  acr_id              = module.acr.acr_id
  node_count          = 2
  enable_auto_scaling = true
  min_count           = 1
  max_count           = 3
}