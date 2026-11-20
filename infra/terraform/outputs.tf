output "central_log_analytics_workspace_id" {
  description = "Resource ID of the platform-owned central Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.central.id
}

output "central_log_analytics_workspace_customer_id" {
  description = "Customer ID of the platform-owned central Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.central.workspace_id
}

output "connectivity_hub_virtual_network_id" {
  description = "Resource ID of the platform-owned connectivity hub virtual network"
  value       = module.connectivity_hub.resource_id["primary"]
}

output "connectivity_firewall_id" {
  description = "Resource ID of the Azure Firewall in the connectivity hub"
  value       = module.connectivity_hub.firewall_resource_ids["primary"]
}

output "connectivity_firewall_private_ip_address" {
  description = "Private IP address of the Azure Firewall in the connectivity hub"
  value       = module.connectivity_hub.firewall_private_ip_addresses["primary"]
}

output "connectivity_firewall_policy_id" {
  description = "Resource ID of the owner-governed Azure Firewall Policy"
  value       = azurerm_firewall_policy.connectivity.id
}

output "connectivity_user_subnet_route_table_id" {
  description = "Resource ID of the hub route table for user subnet traffic"
  value       = module.connectivity_hub.route_tables_user_subnets["primary"].id
}

output "workload_virtual_network_id" {
  description = "Resource ID of the workload virtual network"
  value       = azurerm_virtual_network.workload.id
}

output "workload_foundry_agent_subnet_id" {
  description = "Resource ID of the dedicated Foundry Agent Service subnet"
  value       = azurerm_subnet.foundry_agent.id
}

output "workload_private_endpoint_subnet_id" {
  description = "Resource ID of the workload private endpoint subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "workload_route_table_id" {
  description = "Resource ID of the workload route table that sends Foundry agent subnet egress to Azure Firewall"
  value       = azurerm_route_table.workload.id
}

output "workload_private_dns_zone_ids" {
  description = "Resource IDs of the workload service private DNS zones"
  value       = { for key, zone in azurerm_private_dns_zone.workload_services : key => zone.id }
}

output "foundry_account_id" {
  description = "Resource ID of the private Microsoft Foundry account"
  value       = azapi_resource.foundry_account.id
}

output "foundry_project_id" {
  description = "Resource ID of the standard Foundry Agent Service project"
  value       = azapi_resource.foundry_project.id
}

output "foundry_project_managed_identity_principal_id" {
  description = "Principal ID of the Foundry project system-assigned managed identity"
  value       = azapi_resource.foundry_project.output.identity.principalId
}

output "foundry_cosmosdb_account_id" {
  description = "Resource ID of the customer-owned Foundry Cosmos DB account"
  value       = azurerm_cosmosdb_account.foundry.id
}

output "foundry_storage_account_id" {
  description = "Resource ID of the customer-owned Foundry Storage account"
  value       = azurerm_storage_account.foundry.id
}

output "foundry_search_service_id" {
  description = "Resource ID of the customer-owned Foundry IQ Search service"
  value       = azurerm_search_service.foundry.id
}

output "foundry_key_vault_id" {
  description = "Resource ID of the customer-owned Foundry Key Vault"
  value       = azurerm_key_vault.foundry.id
}
