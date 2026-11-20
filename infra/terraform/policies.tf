locals {
  workload_management_group_id = format(
    "/providers/Microsoft.Management/managementGroups/%s",
    var.subscription_placement["workload"].management_group_name
  )

  private_network_builtin_policies = {
    azure_ai_search = {
      display_name         = "Azure AI Search services should disable public network access"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ee980b6d-0eca-4501-8d54-f6290fd512c3"
      assignment_name      = "deny-public-ai-search"
    }
    cosmos_db = {
      display_name         = "Azure Cosmos DB should disable public network access"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/797b37f7-06b8-444c-b1ad-fc62867f335a"
      assignment_name      = "deny-public-cosmos"
    }
    key_vault = {
      display_name         = "Azure Key Vault should disable public network access"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/405c5871-3e91-4644-8a63-58e19d68ff5b"
      assignment_name      = "deny-public-key-vault"
    }
  }

  private_network_custom_policies = {
    cognitive_services = {
      display_name    = "Cognitive Services accounts must disable public network access"
      resource_type   = "Microsoft.CognitiveServices/accounts"
      access_field    = "Microsoft.CognitiveServices/accounts/publicNetworkAccess"
      mode            = "Indexed"
      assignment_name = "deny-public-cogsvc"
    }
    storage = {
      display_name    = "Storage accounts must disable public network access"
      resource_type   = "Microsoft.Storage/storageAccounts"
      access_field    = "Microsoft.Storage/storageAccounts/publicNetworkAccess"
      mode            = "All"
      assignment_name = "deny-public-storage"
    }
  }
}

resource "azurerm_management_group_policy_assignment" "private_network_builtin" {
  for_each = local.private_network_builtin_policies

  name                 = each.value.assignment_name
  display_name         = each.value.display_name
  management_group_id  = local.workload_management_group_id
  policy_definition_id = each.value.policy_definition_id
  description          = "Require private network access for customer-owned Foundry dependencies."
  enforce              = true
  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })

  depends_on = [module.alz_platform]
}

resource "azurerm_policy_definition" "deny_public_network_access" {
  for_each = local.private_network_custom_policies

  name                = "deny-public-${each.key}"
  display_name        = each.value.display_name
  description         = "Denies resources when public network access is enabled."
  management_group_id = local.workload_management_group_id
  policy_type         = "Custom"
  mode                = each.value.mode

  policy_rule = jsonencode({
    "if" = {
      allOf = [
        {
          field  = "type"
          equals = each.value.resource_type
        },
        {
          field     = each.value.access_field
          notEquals = "Disabled"
        }
      ]
    }
    "then" = {
      effect = "deny"
    }
  })

  depends_on = [module.alz_platform]
}

resource "azurerm_management_group_policy_assignment" "deny_public_network_access" {
  for_each = local.private_network_custom_policies

  name                 = each.value.assignment_name
  display_name         = each.value.display_name
  management_group_id  = local.workload_management_group_id
  policy_definition_id = azurerm_policy_definition.deny_public_network_access[each.key].id
  description          = "Requires public network access to remain disabled for Foundry and its dependencies."
  enforce              = true
}

locals {
  public_access_policy_assignment_ids = merge(
    {
      for key, assignment in azurerm_management_group_policy_assignment.private_network_builtin :
      key => assignment.id
    },
    {
      for key, assignment in azurerm_management_group_policy_assignment.deny_public_network_access :
      key => assignment.id
    }
  )
}

resource "azurerm_resource_policy_exemption" "public_access" {
  for_each = var.public_access_exemptions

  name                 = "public-access-${each.key}"
  resource_id          = each.value.resource_id
  policy_assignment_id = local.public_access_policy_assignment_ids[each.value.policy_key]
  exemption_category   = "Waiver"
  display_name         = "Approved public access exception: ${each.key}"
  description          = "${each.value.rationale} Approval: ${each.value.approval_reference}; owner: ${each.value.owner}."
  expires_on           = each.value.expires_on

  metadata = jsonencode({
    owner              = each.value.owner
    approval_reference = each.value.approval_reference
    rationale          = each.value.rationale
  })
}
