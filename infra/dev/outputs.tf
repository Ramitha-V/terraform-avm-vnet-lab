output "virtual_network_id" {
  description = "Resource ID of the deployed VNet."
  value       = module.vnet.resource_id
}

output "virtual_network_name" {
  description = "Name of the deployed VNet."
  value       = module.vnet.name
}

output "resource_group_name" {
  description = "Resource group that contains the deployed VNet."
  value       = azurerm_resource_group.network.name
}
