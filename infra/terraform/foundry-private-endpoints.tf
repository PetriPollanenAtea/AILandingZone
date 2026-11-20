resource "azurerm_private_endpoint" "foundry_account" {
  provider = azurerm.workload

  name                = "pe-${var.foundry_account_name}"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.foundry_workload_tags

  private_service_connection {
    name                           = "psc-${var.foundry_account_name}"
    private_connection_resource_id = azapi_resource.foundry_account.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.workload_services["foundry_cognitive_services"].id,
      azurerm_private_dns_zone.workload_services["foundry_openai"].id,
      azurerm_private_dns_zone.workload_services["foundry_services_ai"].id,
    ]
  }
}

resource "azurerm_private_endpoint" "foundry_storage" {
  provider = azurerm.workload

  name                = "pe-${var.foundry_storage_account_name}-blob"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.foundry_workload_tags

  private_service_connection {
    name                           = "psc-${var.foundry_storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.foundry.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.workload_services["storage_blob"].id]
  }
}

resource "azurerm_private_endpoint" "foundry_cosmosdb" {
  provider = azurerm.workload

  name                = "pe-${var.foundry_cosmosdb_account_name}"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.foundry_workload_tags

  private_service_connection {
    name                           = "psc-${var.foundry_cosmosdb_account_name}"
    private_connection_resource_id = azurerm_cosmosdb_account.foundry.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.workload_services["cosmos_db_sql"].id]
  }
}

resource "azurerm_private_endpoint" "foundry_search" {
  provider = azurerm.workload

  name                = "pe-${var.foundry_search_service_name}"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.foundry_workload_tags

  private_service_connection {
    name                           = "psc-${var.foundry_search_service_name}"
    private_connection_resource_id = azurerm_search_service.foundry.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.workload_services["azure_ai_search"].id]
  }
}

resource "azurerm_private_endpoint" "foundry_key_vault" {
  provider = azurerm.workload

  name                = "pe-${var.foundry_key_vault_name}"
  location            = azurerm_resource_group.foundry.location
  resource_group_name = azurerm_resource_group.foundry.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.foundry_workload_tags

  private_service_connection {
    name                           = "psc-${var.foundry_key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.foundry.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.workload_services["key_vault"].id]
  }
}
