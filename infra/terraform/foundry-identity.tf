resource "azurerm_role_assignment" "foundry_project_cosmos_operator" {
  provider = azurerm.workload

  scope                = azurerm_cosmosdb_account.foundry.id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_cosmosdb_sql_role_assignment" "foundry_project_data_contributor" {
  provider = azurerm.workload

  resource_group_name = azurerm_resource_group.foundry.name
  account_name        = azurerm_cosmosdb_account.foundry.name
  role_definition_id  = "${azurerm_cosmosdb_account.foundry.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azapi_resource.foundry_project.output.identity.principalId
  scope               = "${azurerm_cosmosdb_account.foundry.id}/dbs/${var.foundry_cosmosdb_runtime_database_name}"
}

resource "azurerm_role_assignment" "foundry_project_storage_account_contributor" {
  provider = azurerm.workload

  scope                = azurerm_storage_account.foundry.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "foundry_project_blob_contributor" {
  provider = azurerm.workload

  scope = "${azurerm_storage_account.foundry.id}/blobServices/default/containers/${var.foundry_file_blob_container_name}"

  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "foundry_project_blob_owner" {
  provider = azurerm.workload

  scope = "${azurerm_storage_account.foundry.id}/blobServices/default/containers/${var.foundry_agent_blob_container_name}"

  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "foundry_project_search_index_contributor" {
  provider = azurerm.workload

  scope                = azurerm_search_service.foundry.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "foundry_project_search_service_contributor" {
  provider = azurerm.workload

  scope                = azurerm_search_service.foundry.id
  role_definition_name = "Search Service Contributor"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "foundry_project_key_vault_secrets_user" {
  provider = azurerm.workload

  scope                = azurerm_key_vault.foundry.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azapi_resource.foundry_project.output.identity.principalId
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}
