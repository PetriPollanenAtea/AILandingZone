locals {
  workload_network_tags = {
    environment = var.environment
    managed_by  = "terraform"
  }

  workload_private_dns_zone_names = {
    foundry_cognitive_services = "privatelink.cognitiveservices.azure.com"
    foundry_openai             = "privatelink.openai.azure.com"
    foundry_services_ai        = "privatelink.services.ai.azure.com"
    azure_ai_search            = "privatelink.search.windows.net"
    cosmos_db_sql              = "privatelink.documents.azure.com"
    storage_blob               = "privatelink.blob.core.windows.net"
    key_vault                  = "privatelink.vaultcore.azure.net"
  }

  workload_private_dns_virtual_networks = merge(
    {
      workload         = azurerm_virtual_network.workload.id
      connectivity_hub = module.connectivity_hub.resource_id["primary"]
    },
    {
      for virtual_network_id in var.authorized_operator_virtual_network_ids :
      "operator-${substr(sha1(lower(virtual_network_id)), 0, 12)}" => virtual_network_id
    },
  )

  workload_private_dns_zone_links = {
    for pair in setproduct(
      keys(local.workload_private_dns_zone_names),
      keys(local.workload_private_dns_virtual_networks),
    ) :
    "${pair[0]}-${pair[1]}" => {
      zone_key            = pair[0]
      virtual_network_key = pair[1]
    }
  }
}

resource "azurerm_resource_group" "workload_network" {
  provider = azurerm.workload

  name     = var.workload_network_resource_group_name
  location = var.region
  tags     = local.workload_network_tags
}

resource "azurerm_virtual_network" "workload" {
  provider = azurerm.workload

  name                = var.workload_virtual_network_name
  location            = azurerm_resource_group.workload_network.location
  resource_group_name = azurerm_resource_group.workload_network.name
  address_space       = var.workload_virtual_network_address_space
  tags                = local.workload_network_tags

  lifecycle {
    precondition {
      condition = (
        alltrue(flatten([
          for workload_prefix in var.workload_virtual_network_address_space : [
            for hub_prefix in var.connectivity_hub_address_space :
            try(
              !cidrcontains(hub_prefix, cidrhost(workload_prefix, 0)) &&
              !cidrcontains(hub_prefix, cidrhost(workload_prefix, -1)) &&
              !cidrcontains(workload_prefix, cidrhost(hub_prefix, 0)) &&
              !cidrcontains(workload_prefix, cidrhost(hub_prefix, -1)),
              false
            )
          ]
        ])) &&
        alltrue(flatten([
          for left_index, left_prefix in var.workload_virtual_network_address_space : [
            for right_index, right_prefix in var.workload_virtual_network_address_space :
            left_index >= right_index ? true : try(
              !cidrcontains(right_prefix, cidrhost(left_prefix, 0)) &&
              !cidrcontains(right_prefix, cidrhost(left_prefix, -1)) &&
              !cidrcontains(left_prefix, cidrhost(right_prefix, 0)) &&
              !cidrcontains(left_prefix, cidrhost(right_prefix, -1)),
              false
            )
          ]
        ]))
      )
      error_message = "Workload address spaces must not overlap each other or the connectivity hub."
    }

    precondition {
      condition = (
        alltrue([
          for subnet_prefix in [
            var.foundry_agent_subnet_address_prefix,
            var.private_endpoint_subnet_address_prefix,
          ] :
          anytrue([
            for vnet_prefix in var.workload_virtual_network_address_space :
            try(
              cidrcontains(vnet_prefix, cidrhost(subnet_prefix, 0)) &&
              cidrcontains(vnet_prefix, cidrhost(subnet_prefix, -1)),
              false
            )
          ])
        ]) &&
        try(
          !cidrcontains(
            var.foundry_agent_subnet_address_prefix,
            cidrhost(var.private_endpoint_subnet_address_prefix, 0)
          ) &&
          !cidrcontains(
            var.foundry_agent_subnet_address_prefix,
            cidrhost(var.private_endpoint_subnet_address_prefix, -1)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost(var.foundry_agent_subnet_address_prefix, 0)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost(var.foundry_agent_subnet_address_prefix, -1)
          ),
          false
        )
      )
      error_message = "The Foundry agent and private endpoint subnets must both fit inside the workload VNet and must not overlap."
    }
  }
}

resource "azurerm_subnet" "foundry_agent" {
  provider = azurerm.workload

  name                 = var.foundry_agent_subnet_name
  resource_group_name  = azurerm_resource_group.workload_network.name
  virtual_network_name = azurerm_virtual_network.workload.name
  address_prefixes     = [var.foundry_agent_subnet_address_prefix]

  delegation {
    name = "foundry-agent-service"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }

  lifecycle {
    precondition {
      condition = (
        can(cidrnetmask(var.foundry_agent_subnet_address_prefix)) &&
        try(tonumber(split("/", var.foundry_agent_subnet_address_prefix)[1]) <= 27, false) &&
        try(
          (
            cidrcontains("10.0.0.0/8", cidrhost(var.foundry_agent_subnet_address_prefix, 0)) &&
            cidrcontains("10.0.0.0/8", cidrhost(var.foundry_agent_subnet_address_prefix, -1))
          ) ||
          (
            cidrcontains("172.16.0.0/12", cidrhost(var.foundry_agent_subnet_address_prefix, 0)) &&
            cidrcontains("172.16.0.0/12", cidrhost(var.foundry_agent_subnet_address_prefix, -1))
          ) ||
          (
            cidrcontains("192.168.0.0/16", cidrhost(var.foundry_agent_subnet_address_prefix, 0)) &&
            cidrcontains("192.168.0.0/16", cidrhost(var.foundry_agent_subnet_address_prefix, -1))
          ),
          false
        ) &&
        anytrue([
          for vnet_prefix in var.workload_virtual_network_address_space :
          try(
            cidrcontains(vnet_prefix, cidrhost(var.foundry_agent_subnet_address_prefix, 0)) &&
            cidrcontains(vnet_prefix, cidrhost(var.foundry_agent_subnet_address_prefix, -1)),
            false
          )
        ])
      )
      error_message = "The Foundry agent subnet must be an RFC 1918 IPv4 CIDR of /27 or larger wholly contained in the workload VNet."
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  provider = azurerm.workload

  name                              = var.private_endpoint_subnet_name
  resource_group_name               = azurerm_resource_group.workload_network.name
  virtual_network_name              = azurerm_virtual_network.workload.name
  address_prefixes                  = [var.private_endpoint_subnet_address_prefix]
  private_endpoint_network_policies = "Disabled"

  lifecycle {
    precondition {
      condition = (
        can(cidrnetmask(var.private_endpoint_subnet_address_prefix)) &&
        anytrue([
          for vnet_prefix in var.workload_virtual_network_address_space :
          try(
            cidrcontains(vnet_prefix, cidrhost(var.private_endpoint_subnet_address_prefix, 0)) &&
            cidrcontains(vnet_prefix, cidrhost(var.private_endpoint_subnet_address_prefix, -1)),
            false
          )
        ]) &&
        try(
          !cidrcontains(
            "192.168.0.0/24",
            cidrhost(var.private_endpoint_subnet_address_prefix, 0)
          ) &&
          !cidrcontains(
            "192.168.0.0/24",
            cidrhost(var.private_endpoint_subnet_address_prefix, -1)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost("192.168.0.0/24", 0)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost("192.168.0.0/24", -1)
          ),
          false
        ) &&
        try(
          !cidrcontains(
            var.foundry_agent_subnet_address_prefix,
            cidrhost(var.private_endpoint_subnet_address_prefix, 0)
          ) &&
          !cidrcontains(
            var.foundry_agent_subnet_address_prefix,
            cidrhost(var.private_endpoint_subnet_address_prefix, -1)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost(var.foundry_agent_subnet_address_prefix, 0)
          ) &&
          !cidrcontains(
            var.private_endpoint_subnet_address_prefix,
            cidrhost(var.foundry_agent_subnet_address_prefix, -1)
          ),
          false
        )
      )
      error_message = "The private endpoint subnet must be an IPv4 CIDR inside the workload VNet, separate from the Foundry agent subnet, and avoid 192.168.0.0/24."
    }
  }
}

resource "azurerm_route_table" "workload" {
  provider = azurerm.workload

  name                = "rt-${var.resource_prefix}-${var.environment}-${var.region}"
  location            = azurerm_resource_group.workload_network.location
  resource_group_name = azurerm_resource_group.workload_network.name
  tags                = local.workload_network_tags
}

resource "azurerm_route" "workload_default_to_firewall" {
  provider = azurerm.workload

  name                   = "default-to-connectivity-firewall"
  resource_group_name    = azurerm_resource_group.workload_network.name
  route_table_name       = azurerm_route_table.workload.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.connectivity_hub.firewall_private_ip_addresses["primary"]
}

resource "azurerm_subnet_route_table_association" "foundry_agent" {
  provider = azurerm.workload

  subnet_id      = azurerm_subnet.foundry_agent.id
  route_table_id = azurerm_route_table.workload.id

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.approved_egress,
  ]
}

resource "azurerm_virtual_network_peering" "workload_to_connectivity" {
  provider = azurerm.workload

  name                      = "peer-workload-to-connectivity"
  resource_group_name       = azurerm_resource_group.workload_network.name
  virtual_network_name      = azurerm_virtual_network.workload.name
  remote_virtual_network_id = module.connectivity_hub.resource_id["primary"]

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "connectivity_to_workload" {
  name                      = "peer-connectivity-to-workload"
  resource_group_name       = azurerm_resource_group.connectivity.name
  virtual_network_name      = var.connectivity_hub_virtual_network_name
  remote_virtual_network_id = azurerm_virtual_network.workload.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_private_dns_zone" "workload_services" {
  for_each = local.workload_private_dns_zone_names

  name                = each.value
  resource_group_name = azurerm_resource_group.connectivity.name
  tags                = local.workload_network_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "workload_services" {
  for_each = local.workload_private_dns_zone_links

  name                  = "link-${substr(sha1(each.key), 0, 24)}"
  resource_group_name   = azurerm_resource_group.connectivity.name
  private_dns_zone_name = azurerm_private_dns_zone.workload_services[each.value.zone_key].name
  virtual_network_id    = local.workload_private_dns_virtual_networks[each.value.virtual_network_key]
  registration_enabled  = false
}
