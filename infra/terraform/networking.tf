resource "azurerm_resource_group" "connectivity" {
  name     = var.connectivity_resource_group_name
  location = var.region
  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_firewall_policy" "connectivity" {
  name                     = "fwp-${var.resource_prefix}-${var.environment}-${var.region}"
  resource_group_name      = azurerm_resource_group.connectivity.name
  location                 = azurerm_resource_group.connectivity.location
  sku                      = var.firewall_sku_tier
  threat_intelligence_mode = "Alert"

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "approved_egress" {
  for_each = var.firewall_policy_rule_collection_groups

  name               = each.key
  firewall_policy_id = azurerm_firewall_policy.connectivity.id
  priority           = each.value.priority

  dynamic "application_rule_collection" {
    for_each = each.value.application_rule_collections

    content {
      name     = application_rule_collection.key
      priority = application_rule_collection.value.priority
      action   = "Allow"

      dynamic "rule" {
        for_each = application_rule_collection.value.rules

        content {
          name              = rule.value.name
          source_addresses  = rule.value.source_addresses
          destination_fqdns = rule.value.destination_fqdns

          dynamic "protocols" {
            for_each = rule.value.protocols

            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }

  dynamic "network_rule_collection" {
    for_each = each.value.network_rule_collections

    content {
      name     = network_rule_collection.key
      priority = network_rule_collection.value.priority
      action   = "Allow"

      dynamic "rule" {
        for_each = network_rule_collection.value.rules

        content {
          name                  = rule.value.name
          protocols             = rule.value.protocols
          source_addresses      = rule.value.source_addresses
          destination_addresses = rule.value.destination_addresses
          destination_ports     = rule.value.destination_ports
        }
      }
    }
  }
}

module "connectivity_hub" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.14.1"

  enable_telemetry = false
  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }

  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }
  }

  hub_virtual_networks = {
    primary = {
      is_primary        = true
      location          = var.region
      default_parent_id = azurerm_resource_group.connectivity.id

      enabled_resources = {
        firewall                              = true
        firewall_policy                       = false
        bastion                               = false
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false
        private_dns_zones                     = false
        private_dns_resolver                  = false
        dns_resolver_policy                   = false
        nat_gateway                           = false
      }

      hub_virtual_network = {
        name                                             = var.connectivity_hub_virtual_network_name
        address_space                                    = var.connectivity_hub_address_space
        routing_address_space                            = var.connectivity_hub_address_space
        route_table_firewall_enabled                     = true
        route_table_user_subnets_enabled                 = true
        route_table_user_subnets_bgp_propagation_enabled = false
      }

      firewall = {
        name                  = "fw-${var.resource_prefix}-${var.environment}-${var.region}"
        sku_name              = "AZFW_VNet"
        sku_tier              = var.firewall_sku_tier
        subnet_address_prefix = var.firewall_subnet_address_prefix
        firewall_policy_id    = azurerm_firewall_policy.connectivity.id
        management_ip_enabled = false
      }
    }
  }
}
