resource "azurerm_resource_group" "network" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = "dev"
    managed_by  = "terraform"
    workload    = "avm-lab"
  }
}

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.22.2"

  name          = var.vnet_name
  location      = azurerm_resource_group.network.location
  parent_id     = azurerm_resource_group.network.id
  address_space = var.address_space

  subnets = {
    app = {
      name             = "snet-app-dev"
      address_prefixes = ["10.20.1.0/24"]
    }
    data = {
      name             = "snet-data-dev"
      address_prefixes = ["10.20.2.0/24"]
    }
  }

  tags = azurerm_resource_group.network.tags
}
