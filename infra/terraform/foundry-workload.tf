locals {
  foundry_workload_tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "foundry" {
  provider = azurerm.workload

  name     = var.foundry_resource_group_name
  location = var.region
  tags     = local.foundry_workload_tags
}

resource "azurerm_storage_account" "foundry" {
  provider = azurerm.workload

  name                            = var.foundry_storage_account_name
  resource_group_name             = azurerm_resource_group.foundry.name
  location                        = azurerm_resource_group.foundry.location
  account_tier                    = "Standard"
  account_replication_type        = var.foundry_storage_replication_type
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  tags                            = local.foundry_workload_tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.foundry_blob_soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.foundry_container_soft_delete_retention_days
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["None"]
  }
}

resource "azurerm_cosmosdb_account" "foundry" {
  provider = azurerm.workload

  name                               = var.foundry_cosmosdb_account_name
  location                           = azurerm_resource_group.foundry.location
  resource_group_name                = azurerm_resource_group.foundry.name
  offer_type                         = "Standard"
  kind                               = "GlobalDocumentDB"
  local_authentication_enabled       = false
  public_network_access_enabled      = false
  automatic_failover_enabled         = false
  is_virtual_network_filter_enabled  = false
  access_key_metadata_writes_enabled = false
  minimal_tls_version                = "Tls12"
  tags                               = local.foundry_workload_tags

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.region
    failover_priority = 0
    zone_redundant    = var.foundry_cosmosdb_zone_redundant
  }

  capacity {
    total_throughput_limit = var.foundry_cosmosdb_total_throughput_limit
  }

  backup {
    type                = var.foundry_cosmosdb_backup.type
    tier                = var.foundry_cosmosdb_backup.tier
    interval_in_minutes = var.foundry_cosmosdb_backup.interval_in_minutes
    retention_in_hours  = var.foundry_cosmosdb_backup.retention_in_hours
    storage_redundancy  = var.foundry_cosmosdb_backup.storage_redundancy
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_search_service" "foundry" {
  provider = azurerm.workload

  name                          = var.foundry_search_service_name
  resource_group_name           = azurerm_resource_group.foundry.name
  location                      = azurerm_resource_group.foundry.location
  sku                           = var.foundry_search_sku
  local_authentication_enabled  = false
  public_network_access_enabled = false
  tags                          = local.foundry_workload_tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault" "foundry" {
  provider = azurerm.workload

  name                          = var.foundry_key_vault_name
  location                      = azurerm_resource_group.foundry.location
  resource_group_name           = azurerm_resource_group.foundry.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = var.foundry_key_vault_soft_delete_retention_days
  purge_protection_enabled      = true
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  tags                          = local.foundry_workload_tags
}

resource "azapi_resource" "foundry_account" {
  provider = azapi.workload

  type      = "Microsoft.CognitiveServices/accounts@2026-11-15-preview"
  name      = var.foundry_account_name
  parent_id = azurerm_resource_group.foundry.id
  location  = azurerm_resource_group.foundry.location
  tags      = local.foundry_workload_tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    properties = {
      customSubDomainName = var.foundry_account_name
      publicNetworkAccess = "Disabled"
      disableLocalAuth    = true
      userOwnedStorage = [
        {
          resourceId = azurerm_storage_account.foundry.id
        }
      ]
      capabilitySettings = {
        documentStore = azurerm_cosmosdb_account.foundry.id
        vectorStore   = azurerm_search_service.foundry.id
        blobStore     = azurerm_storage_account.foundry.id
      }
      networkInjections = [
        {
          scenario                   = "agent"
          subnetArmId                = azurerm_subnet.foundry_agent.id
          useMicrosoftManagedNetwork = false
        }
      ]
    }
  }

  response_export_values = ["identity"]

  replace_triggers_external_values = [
    azurerm_cosmosdb_account.foundry.id,
    azurerm_search_service.foundry.id,
    azurerm_storage_account.foundry.id,
    azurerm_subnet.foundry_agent.id,
  ]

  schema_validation_enabled = false

  lifecycle {
    prevent_destroy = true

    precondition {
      condition = alltrue([
        length(trimspace(var.foundry_region_capability_evidence_reference)) > 0,
        length(trimspace(var.foundry_preview_api_support_evidence_reference)) > 0,
        length(trimspace(var.foundry_capability_provisioner_access_evidence_reference)) > 0,
        length(trimspace(var.foundry_recovery_approval_reference)) > 0,
      ])
      error_message = "Foundry model/tool quota, preview API support, provisioner access, and D2 recovery evidence references are required before provisioning."
    }
  }
}

resource "azapi_resource" "foundry_project" {
  provider = azapi.workload

  type      = "Microsoft.CognitiveServices/accounts/projects@2026-11-15-preview"
  name      = var.foundry_project_name
  parent_id = azapi_resource.foundry_account.id
  location  = azurerm_resource_group.foundry.location
  tags      = local.foundry_workload_tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      displayName = var.foundry_project_display_name
      description = "Standard Agent Service project with customer-owned state resources"
    }
  }

  response_export_values    = ["identity"]
  schema_validation_enabled = false

  lifecycle {
    prevent_destroy = true
  }
}
