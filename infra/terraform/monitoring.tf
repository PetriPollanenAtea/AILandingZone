locals {
  operations_tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_resource_group" "platform_operations" {
  name     = var.platform_operations_resource_group_name
  location = var.region
  tags     = local.operations_tags
}

resource "azurerm_log_analytics_workspace" "central" {
  name                            = var.log_analytics_workspace_name
  location                        = azurerm_resource_group.platform_operations.location
  resource_group_name             = azurerm_resource_group.platform_operations.name
  sku                             = "PerGB2018"
  retention_in_days               = var.diagnostic_retention_in_days
  local_authentication_enabled    = false
  allow_resource_only_permissions = false
  tags                            = local.operations_tags
}

resource "azurerm_role_assignment" "log_analytics_reader" {
  for_each = var.authorized_log_reader_principal_ids

  name                 = uuidv5("url", "${azurerm_log_analytics_workspace.central.id}/log-analytics-reader/${each.value}")
  scope                = azurerm_log_analytics_workspace.central.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = each.value
}

resource "azurerm_monitor_diagnostic_setting" "platform" {
  for_each = var.platform_diagnostic_targets

  name                       = "central-operations"
  target_resource_id         = each.value.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id

  dynamic "enabled_log" {
    for_each = each.value.log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = each.value.metric_categories
    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "workload" {
  provider = azurerm.workload
  for_each = var.workload_diagnostic_targets

  name                       = "central-operations"
  target_resource_id         = each.value.resource_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.central.id

  dynamic "enabled_log" {
    for_each = each.value.log_categories
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = each.value.metric_categories
    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_consumption_budget_subscription" "this" {
  for_each = var.cost_budgets

  name            = "alz-${each.key}-${var.environment}"
  subscription_id = var.subscription_placement[each.key].subscription_id
  amount          = each.value.amount
  time_grain      = each.value.time_grain

  time_period {
    start_date = each.value.start_date
  }

  dynamic "notification" {
    for_each = {
      actual = {
        threshold      = each.value.actual_threshold
        threshold_type = "Actual"
      }
      forecasted = {
        threshold      = each.value.forecasted_threshold
        threshold_type = "Forecasted"
      }
    }

    content {
      enabled        = true
      operator       = "GreaterThan"
      threshold      = notification.value.threshold
      threshold_type = notification.value.threshold_type
      contact_emails = each.value.contact_emails
    }
  }
}
